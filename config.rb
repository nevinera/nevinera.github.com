require "slim"

# Activate and configure extensions
# https://middlemanapp.com/advanced/configuration/#configuring-extensions

activate :autoprefixer do |prefix|
  prefix.browsers = "last 2 versions"
end

set :markdown_engine, :redcarpet
set :markdown, :fenced_code_blocks => true, :smartypants => true

# Layouts
# https://middlemanapp.com/basics/layouts/

# Per-page layout changes
page '/*.xml', layout: false
page '/*.json', layout: false
page '/*.txt', layout: false

# With alternative layout
# page '/path/to/file.html', layout: 'other_layout'

# Proxy pages
# https://middlemanapp.com/advanced/dynamic-pages/

# proxy(
#   '/this-page-has-no-template.html',
#   '/template-file.html',
#   locals: {
#     which_fake_page: 'Rendering a fake page with a local variable'
#   },
# )

# Helpers
# Methods defined in the helpers block are available in templates
# https://middlemanapp.com/basics/helper-methods/

PostData = Struct.new(:title, :date, :summary, :published, :path, :filepath, keyword_init: true)

helpers do
  def post_paths
    glob = File.expand_path("source/posts/*", __dir__)
    Dir.glob(glob).to_a.sort.reverse
  end

  def all_posts
    post_paths.map do |path|
      file = app.files.find(:source, path)
      data, _content_source = ::Middleman::Util::Data.parse(file, app.config[:frontmatter_delims])
      slug = File.basename(path, ".html.md")
      PostData.new(**data.merge(filepath: path, path: "/posts/#{slug}.html"))
    end
  end

  def public_posts
    all_posts.select(&:published)
  end
end

# Build-specific configuration
# https://middlemanapp.com/advanced/configuration/#environment-specific-settings

# configure :build do
#   activate :minify_css
#   activate :minify_javascript, compressor: Terser.new
# end
