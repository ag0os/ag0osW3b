# One line in, one exchange out. The form on the home page submits here with
# GET, so a command is a URL and the page works with JavaScript off.
#
# With JavaScript on, Turbo asks for a stream and the exchange is appended in
# place. Without it, the answer is the home page rendered with the exchange
# after the opening. `open` and `lang` change where the visitor is rather than
# what is printed, so they redirect either way; Turbo follows a redirect from
# a form as a visit, which for `lang` is the point: the whole page, nav and
# footer included, comes back in the new language.
class ShellController < SiteController
  def show
    @result = Shell.run(params[:line])

    case @result.view
    when :open then redirect_to helpers.shell_pages.fetch(@result.locals[:page])
    when :lang then switch_language(@result.locals[:locale])
    else
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to root_path(line: @result.line) }
      end
    end
  end

  private
    # The cookie outlives the session so a visitor who chose Spanish once is
    # greeted in Spanish next time. Redirecting with the line keeps the
    # confirmation: the home page runs `lang es` again under the new locale
    # and prints "idioma: Español" after the opening.
    def switch_language(locale)
      cookies.permanent[:locale] = { value: locale.to_s, same_site: :lax }
      redirect_to root_path(line: @result.line)
    end
end
