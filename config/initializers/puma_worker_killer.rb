if Rails.env.production?
  PumaWorkerKiller.enable_rolling_restart
end