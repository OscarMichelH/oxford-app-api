require 'date'

module V1
  class NotificationsController < ApplicationController
    before_action :authorize_request
    before_action :comprobe_admin, only: :create

    def index
      @page = 1
      @events = Event&.order(publication_date: :asc)&.order(category: :asc)
      render 'v1/events/index'
    end

    def create
      category = notification_params['category']
      title = notification_params['title']
      description = notification_params['description']
      date = notification_params['publication_date']
      publication_date = DateTime.strptime(date, '%Y/%m/%d').in_time_zone("Monterrey") + 6.hours if date
      role = notification_params['role']
      campuses = notification_params['campuses']&.reject(&:blank?)
      grades = notification_params['grades']&.reject(&:blank?)
      groups = notification_params['groups']&.reject(&:blank?)
      family_keys = notification_params['family_keys']&.reject(&:blank?)
      student_names = notification_params['student_names']&.reject(&:blank?)

      errors = []
      errors << 'Categoria obligatoria' if category.blank?
      errors << 'Titulo obligatorio' if title.blank?
      errors << 'Descripcion obligatoria' if description.blank?

      if publication_date&.today?
        publication_date = DateTime.now + 2.minutes
      elsif publication_date > Time.now
        publication_date = publication_date.change({ hour: 4 })
      end

      if publication_date.blank? || publication_date < Time.now.to_date
        errors << 'Fecha vacio o anterior a hoy'
      end

      return render json: { errors: errors }, status: :internal_server_error if errors.any?
      core_event = Event.new(category: category, title: title, description: description,
                             publication_date: publication_date,
                             role: role, campus: campuses&.join(',')&.upcase,
                             grade: grades&.join(',')&.upcase, group: groups&.join(',')&.upcase,
                             assist: 0, view: 0,
                             created_by: @current_user.id)
      core_event.save
      users = []

      if role == 'ADMIN'
        no_admin_params = true
        no_admin_params = false if grades.present?
        no_admin_params = false if groups.present?
        no_admin_params = false if family_keys.present?
        no_admin_params = false if student_names.present?
        if no_admin_params
          users = User.where(role: 'ADMIN')
          users = users.by_admin_campus(campuses) if campuses.present?
        else
          return render json: { errors: 'Admin notifications can not receive Parent parameters'}, status: :partial_content
        end
      elsif role == 'PARENT'
        kids = Kid.all
        kids = kids.by_campuses(campuses) if campuses.present?
        kids = kids.by_grades(grades) if grades.present?
        kids = kids.by_groups(groups) if groups.present?
        kids = kids.by_family_keys(family_keys) if family_keys.present?
        kids = kids.by_student_names(student_names) if student_names.present?
        kids = kids.uniq{|t| t.family_key } if kids.present?
        kids&.each do |kid|
          kid.users.each { |user| users << user }
        end
      else
        kids = Kid.all
        kids = kids.by_campuses(campuses) if campuses.present?
        kids = kids.by_grades(grades) if grades.present?
        kids = kids.by_groups(groups) if groups.present?
        kids = kids.by_family_keys(family_keys) if family_keys.present?
        kids = kids.by_student_names(student_names) if student_names.present?
        kids = kids.uniq{|t| t.family_key } if kids.present?
        kids&.each do |kid|
          kid&.users.each { |user| users << user }
        end
      end

      # Create notifications on db
      @notifications_created = 0
      users&.each do |user|
        begin
          notification = Notification.new
          notification.category = category
          notification.title = title
          notification.description = description
          notification.publication_date = publication_date
          notification.role = role
          notification.campus = (user.kids&.first&.campus || user.admin_campus)
          notification.group = grades&.join(',')
          notification.group = groups&.join(',') || ''
          notification.family_key = user.family_key
          notification.role = user.role
          notification.created_by = @current_user.id
          notification.user = user
          notification.student_name = student_names&.join(',') || ''
          notification.event = core_event
          user.save!(validate: false)
          core_event.save!
          @notifications_created += 1 if notification.save!
          #&& user.save!(validate: false) && core_event.save!
        rescue

        end
      end

      core_event.total = @notifications_created
      total_kids = 0
      not_view = 0
      core_event&.notifications.each do |notification|
          not_view += 1
          total_kids += notification&.user&.kids&.count
      end
      core_event.not_view = not_view
      core_event.total_kids = total_kids

      if @notifications_created.positive? && core_event.save!
        render :create
      else
        core_event.destroy!
        render json: { errors: 'Users not found for notification delivery'}, status: :partial_content
      end
    end

    def show_by_user_id
      @notifications = Notification.where(user_id: params[:user_id])&.after_date
      if @notifications
        render json: @notifications.order(publication_date: :asc).order(category: :asc)
      else
        head(:unauthorized)
      end
    end

    def update_notification
      @notification = Notification.find(params[:notification_id])
      event = @notification.event
      assist= @notification.assist
      seen = @notification.seen
      if @notification.update(notification_params)
        event.assist += 1 if !assist && @notification.assist
        event.assist -= 1 if assist && !@notification.assist
        if !seen && @notification.seen
          event.view += 1
          event.not_view -= 1
        end
        event.save!
        render json: @notification
      else
        head(:unauthorized)
      end
    end

    def notification_counter_by_user_id
      notifications = Notification.where(user_id: params[:user_id])
      @seen_notifications = notifications.where(seen: true)&.count || 0
      @not_seen_notifications = (notifications&.count || 0) - @seen_notifications
      render 'counters'
    end

    Parent = Struct.new(:email, :assist, :seen, :total_kids, :kids)

    def notifications_group
      @events = Event.all.where(created_by: @current_user.id)
      if params['roles'].present?
        @events = @events.by_role(params['roles']) if contains_str(params['roles'])
      end
      if params['roles'].present?
        @events = @events.by_categories(params['categories']) if contains_str(params['categories'])
      end
      @events = @events.by_title(params['title']) if params['title'].present?
      @events = @events.by_description(params['description']) if params['description'].present?
      date = notification_params['publication_date'] if notification_params['publication_date'].present?
      if date
        params['from_date'] = date
        params['until_date'] = date
      end
      if params['campuses'].present?
        @events = @events.by_campuses(params['campuses']&.join(',')&.upcase) if contains_str(params['campuses'])
      end
      if params['grades'].present?
        @events = @events.by_grades(params['grades']) if contains_str(params['grades'])
      end
      if params['groups'].present?
        @events = @events.by_groups(params['groups']) if contains_str(params['groups'])
      end

      if params['family_keys'].present? && contains_str(params['family_keys'])
        events = []
        User.all.where(family_key: params['family_keys']).each do |user|
          user.notifications.each do |notification|
            events << notification.event
          end
        end
        events.uniq!
        @events = @events.where(id: events)
      end

      if params['from_date'].present? && params['until_date'].present?
        from_date =  DateTime.strptime(params['from_date'], '%Y/%m/%d').in_time_zone("Monterrey") + 6.hours
        until_date = DateTime.strptime(params['until_date'], '%Y/%m/%d').in_time_zone("Monterrey") + 6.hours
        until_date += 24.hours if from_date == until_date

        if from_date < until_date
          @events = @events.with_date(from_date, until_date)
        else
          return render json: { errors: 'Date arrange invalid'}, status: :internal_server_error
        end
      end
      @events&.order(publication_date: :asc)&.order(category: :asc)
      render 'stats'
    end

    def create_notification_from_excel
      workbook = Roo::Excel.new(params[:file].path, file_warning: :ignore)
      workbook.default_sheet = workbook.sheets[0]
      headers = Hash.new
      workbook.row(1).each_with_index {|header,i|
        headers[header] = i
      }

      @users_created = 0
      events = []
      @users_not_created = 0
      ((workbook.first_row + 1)..workbook.last_row).each do |row|
        category = workbook.row(row)[headers['CATEGORIA']]&.to_s
        title = workbook.row(row)[headers['TITULO']]&.to_s
        description = workbook.row(row)[headers['DESCRIPCION']]&.to_s
        date = workbook.row(row)[headers['FECHA DE PUBLICACION']]&.to_s
        publication_date = DateTime.strptime(date, '%d/%m/%Y').in_time_zone("Monterrey") + 6.hours if date
        family_key = workbook.row(row)[headers['CLAVE FAMILIAR']]&.to_i&.to_s if headers['CLAVE FAMILIAR']

        errors = []
        errors << 'Categoria obligatoria' if category.blank?
        errors << 'Titulo obligatorio' if title.blank?
        errors << 'Descripcion obligatoria' if description.blank?

        if publication_date&.today?
          publication_date = DateTime.now + 2.minutes
        elsif publication_date > Time.now
          publication_date = publication_date.change({ hour: 4 })
        end

        if publication_date.blank? || publication_date < Time.now.to_date
          errors << 'Fecha vacio o anterior a hoy'
        end

        grade = Kid.where(family_key: family_key)&.first&.grade
        group = Kid.where(family_key: family_key)&.first&.group
        student_name = Kid.where(family_key: family_key)&.first&.name

        core_event = Event.new(category: category, title: title, description: description,
                               publication_date: publication_date,
                               role: 'PARENT', campus: @current_user.admin_campus,
                               grade: grade, group: group,
                               assist: 0, view: 0, not_view: 1, total: 1,
                               created_by: @current_user.id)

        core_event.save

        users = []

        kids = Kid.all
        kids = kids.by_family_keys(family_key) if family_key.present?
        kids = kids.uniq{|t| t.family_key } if kids.present?
        kids&.each do |kid|
          kid.users.each { |user| users << user }
        end

        # Create notifications on db
        @notifications_created = 0
        users&.each do |user|
          core_event.total_kids = user&.kids&.count,
          notification = Notification.new
          notification.category = category
          notification.title = title
          notification.description = description
          notification.publication_date = publication_date
          notification.role = 'PARENT'
          notification.campus = (user.kids&.first&.campus || user.admin_campus)
          notification.grade = grade
          notification.group = group
          notification.family_key = user.family_key
          notification.role = user.role
          notification.created_by = @current_user.id
          notification.user = user
          notification.event = core_event
          notification.student_name = student_name
          user.save!(validate: false)
          core_event.save!
          events << core_event
          @notifications_created += 1 if notification.save!
        end
      end

      if @notifications_created&.positive?
        return render :create
      else
        Event.where(id: events).destroy_all
        return render json: { errors: 'Users not found for notification delivery'}, status: :partial_content
      end

      return render 'create_from_excel'
    end

    def notify(users, notification)
      devices_ids = []
      users.each do |user|
        devices_ids << user.devices&.pluck(:id)
      end

      devices = Device.where(id: devices_ids)

      if devices.count.positive?
        #get all devices registered in our db and loop through each of them
        devices.each do |device|
          n = Rpush::Gcm::Notification.new
          # use the pushme_droid app we previously registered in our initializer file to send the notification
          n.app = Rpush::Gcm::App.find_by_name("oxford-app-api")
          n.registration_ids = [device.token]

          # parameter for the notification
          n.notification = {
              body: notification.description,
              title: notification.title,
              sound: 'default'
          }
          #save notification entry in the db
          n.save!
        end

        # send all notifications stored in db
        Rpush.push
      end
    end

    private

    def contains_str(array)
      !array&.reject(&:empty?)&.empty?
    end

    def notification_params
      params.require(:notification).permit(:category, :title, :description, :publication_date,
                                           :role,:status, :assist, :seen,
                                           :campuses => [], :grades => [], :groups => [],
                                            :family_keys => [], :student_names => [])
    end
  end
end