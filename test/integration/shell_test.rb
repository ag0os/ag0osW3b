require "test_helper"

# The shell as an HTTP surface: the page it lives on, the stream it answers
# with, and the plain-form path that has to work with JavaScript off.
class ShellFlowTest < ActionDispatch::IntegrationTest
  STREAM = { "Accept" => "text/vnd.turbo-stream.html, text/html" }.freeze

  test "the home page opens on the shell with its greeting already printed" do
    get root_path

    assert_response :success
    assert_select "#shell .shell__cmd", text: "whoami"
    assert_select "#shell .shell__cmd", text: "cat proof"
    assert_select "#shell .shell__cmd", text: "help"
    assert_select "#shell .shell__out", /Test Site/
    assert_select "#shell .shell__out", /Hundreds of organizations/
    assert_select "#shell input[name=line][placeholder=?]", I18n.t("shell.placeholder")
  end

  test "a command is answered as a stream appended to the transcript" do
    get shell_path(line: "help"), headers: STREAM

    assert_response :success
    assert_equal Mime[:turbo_stream], response.media_type
    assert_select "turbo-stream[action=append][target=shell-output]" do
      assert_select ".shell__cmd", text: "help"
      assert_select ".shell__out", /#{I18n.t("shell.help.intro")}/
    end
  end

  test "without javascript the page comes back with the exchange after the opening" do
    get shell_path(line: "cat home")

    assert_redirected_to root_path(line: "cat home")
    follow_redirect!

    assert_select "#shell-output .shell__exchange", 4, "three opening exchanges plus the one just run"
    assert_select "#shell-output .shell__exchange:last-child .shell__cmd", text: "cat home"
    assert_select "#shell mark", text: "home"
  end

  test "without javascript the browser-only commands say so" do
    get shell_path(line: "theme spec")
    follow_redirect!

    assert_select "#shell .shell__out", /JavaScript/
  end

  test "open goes to the page" do
    get shell_path(line: "open work")
    assert_redirected_to work_path

    get shell_path(line: "open nowhere")
    assert_redirected_to root_path(line: "open nowhere")
  end

  test "lang es switches the whole site to Spanish, confirms it, and remembers it" do
    get shell_path(line: "lang es")

    assert_redirected_to root_path(line: "lang es")
    assert_equal "es", cookies["locale"]

    follow_redirect!
    assert_select "html[lang=es]"
    assert_select "#shell-output .shell__exchange:last-child .shell__out", /idioma: Español/
    assert_select "#shell .shell__cmd", text: "whoami", count: 1
    assert_select "#shell input[placeholder=?]", I18n.t("shell.placeholder", locale: :es)
    assert_select "nav a", text: I18n.t("nav.about", locale: :es)

    get about_path
    assert_select "html[lang=es]", true, "the choice did not survive to the next page"
  end

  test "lang es with JavaScript is a full visit rather than a stream, so the nav switches too" do
    get shell_path(line: "lang es"), headers: STREAM

    assert_redirected_to root_path(line: "lang es")
  end

  test "the browser's language is honoured on a first visit" do
    get root_path, headers: { "Accept-Language" => "es-AR,es;q=0.9,en;q=0.8" }

    assert_select "html[lang=es]"
    assert_select "#shell input[placeholder=?]", I18n.t("shell.placeholder", locale: :es)
  end

  test "an unsupported browser language falls back to English" do
    get root_path, headers: { "Accept-Language" => "fr-FR,fr;q=0.9" }

    assert_select "html[lang=en]"
  end

  test "a stored choice beats the browser's language" do
    get shell_path(line: "lang en")
    get root_path, headers: { "Accept-Language" => "es" }

    assert_select "html[lang=en]"
  end

  test "the admin stays in English whatever the visitor chose" do
    get shell_path(line: "lang es")
    get new_session_path

    assert_select "html[lang=en]"
  end

  test "every English string has a Spanish one, and nothing extra" do
    en = flatten(YAML.load_file(Rails.root.join("config/locales/en.yml")).fetch("en"))
    es = flatten(YAML.load_file(Rails.root.join("config/locales/es.yml")).fetch("es"))

    assert_empty en - es, "missing from es.yml"
    assert_empty es - en, "in es.yml but not en.yml"
  end

  private
    def flatten(hash, prefix = nil)
      hash.flat_map do |key, value|
        path = [ prefix, key ].compact.join(".")
        value.is_a?(Hash) ? flatten(value, path) : [ path ]
      end
    end
end
