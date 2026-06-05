# Base controller for the public-facing site. The auth concern requires a
# session by default, so public pages opt out here.
class SiteController < ApplicationController
  allow_unauthenticated_access
end
