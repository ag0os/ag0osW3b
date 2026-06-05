module Admin
  # Inherits `require_authentication` from ApplicationController's Authentication
  # concern, so the whole /admin area is login-only.
  class BaseController < ApplicationController
    layout "admin"
  end
end
