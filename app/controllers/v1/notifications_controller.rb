require 'date'

module V1
  class NotificationsController < ApplicationController
    before_action :authorize_request
    before_action :comprobe_admin, only: :create

    def index
      render json: Notification.all.where(created_by: @current_user.id).order(publication_date: :asc).order(category: :asc)
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
      event_id = (Notification.last&.event_id&.to_i) || 0
      event_id += 1

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

      core_notification = Notification.new(title: title, description: description, publication_date: publication_date, created_by: @current_user.id)

      return render json: { errors: errors }, status: :internal_server_error if errors.any?
      
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
        users = User.all
        users = users.by_admin_campus(campuses) if campuses.present?
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
      end

      # Create notifications on db
      @notifications_created = 0
      users&.each do |user|
        begin
          notification = user.notifications.new(category: category, title: title, description: description,
                                                campus: (user.kids&.first&.campus || user.admin_campus),
                                                event_id: event_id, publication_date: publication_date, role: user.role,
                                                grade: grades&.join(',') || '', group: groups&.join(',') || '', family_key: user.family_key, created_by: @current_user.id)
          @notifications_created += 1 if notification.save! && user.save!(validate: false)
        rescue

        end

      end

      if @notifications_created.positive?
        begin
          notify(users, core_notification)
        rescue

        end
        render :create
      else
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
      if @notification.update(notification_params)
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
      @notifications = Notification.all.where(created_by: @current_user.id)
      @notifications = @notifications.by_role(params['roles']) if params['roles'].present?
      @notifications = @notifications.by_categories(params['categories']) if params['categories'].present?
      @notifications = @notifications.by_title(params['title']) if params['title'].present?
      @notifications = @notifications.by_description(params['description']) if params['description'].present?
      date = notification_params['publication_date'] if notification_params['publication_date'].present?
      if date
        params['from_date'] = date
        params['until_date'] = date
      end

      @notifications = @notifications.by_campuses(params['campuses']) if params['campuses'].present?
      @notifications = @notifications.by_grades(params['grades']) if params['grades'].present?
      @notifications = @notifications.by_groups(params['groups']) if params['groups'].present?
      @notifications = @notifications.by_family_keys(params['family_keys']) if params['family_keys'].present?
      if params['from_date'].present? && params['until_date'].present?
        from_date =  DateTime.strptime(params['from_date'], '%Y/%m/%d').in_time_zone("Monterrey") + 6.hours
        until_date = DateTime.strptime(params['until_date'], '%Y/%m/%d').in_time_zone("Monterrey") + 6.hours
        until_date += 24.hours if from_date == until_date

        if from_date < until_date
          @notifications = @notifications.with_date(from_date, until_date)
        else
          return render json: { errors: 'Date arrange invalid'}, status: :internal_server_error
        end
      end

      events = @notifications.distinct.pluck(:event_id)
      @totals = []
      @assists = []
      @views = []
      @not_views = []
      @related_kids = []
      @parents = []
      @individual_assists = []
      @individual_seen = []
      @total_kids = []
      events.each do |event|
        group = Notification.all.where(event_id: event)
        parents = []
        total_kids = 0
        group.each do |notification|
          parent_kids = notification&.user&.kids&.count
          total_kids += parent_kids
          parent = Parent.new(notification&.user&.email, notification.assist, notification.seen, parent_kids, notification&.user&.kids)
          parents << parent
        end
        @total_kids << total_kids
        @parents << parents
        total = group.count
        @totals << total
        assist = group.where(assist: true).count
        @assists << assist
        views = group.where(seen: true).count
        @views << views
        @not_views << total-views
      end
      @notifications&.order(publication_date: :asc)&.order(category: :asc)
      @events_found = @notifications.count
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

      @users_not_created = 0
      ((workbook.first_row + 1)..workbook.last_row).each do |row|
        category = workbook.row(row)[headers['CATEGORIA']]&.to_s
        title = workbook.row(row)[headers['TITULO']]&.to_s
        description = workbook.row(row)[headers['DESCRIPCION']]&.to_s
        date = workbook.row(row)[headers['FECHA DE PUBLICACION']]&.to_s
        publication_date = DateTime.strptime(date, '%Y-%d-%m').in_time_zone("Monterrey") + 6.hours if date
        family_key = workbook.row(row)[headers['CLAVE FAMILIAR']]&.to_s if headers['CLAVE FAMILIAR']

        event_id = (Notification.last&.event_id&.to_i) || 0
        event_id += 1

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

        core_notification = Notification.new(title: title, description: description, publication_date: publication_date)

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
          notification = user.notifications.new(category: category, title: title, description: description, campus: user.kids&.first&.campus,
                                                event_id: event_id, publication_date: publication_date, role: user.role, family_key: user.family_key, created_by: @current_user.id)
          @notifications_created += 1 if notification.save! && user.save!(validate: false)
        end
      end

      if @notifications_created&.positive?
        begin
          notify(users, core_notification)
        rescue

        end
        return render :create
      else
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

    def notification_params
      params.require(:notification).permit(:category, :title, :description, :publication_date,
                                           :role,:status, :assist, :event_id, :seen,
                                           :campuses => [], :grades => [], :groups => [],
                                            :family_keys => [], :student_names => [])
    end
  end
end