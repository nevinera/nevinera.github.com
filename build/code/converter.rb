require 'date'
require 'slim'
require 'redcarpet'
require 'pry'
require 'sass'

class Converter
	attr_accessor :build_path, :site_path, :layouts, :css_paths

	def initialize(opts={})
		self.build_path = opts[:build_path] || File.expand_path(File.basename(__FILE__) + "/..")
		self.site_path = opts[:site_path] || File.expand_path(build_path + "/..")
		self.layouts = {}
		self.css_paths = []
	end

	def build_site!
		self.build_styles
		self.read_layouts
		self.clean_out_posts
		self.build_posts
	end

	def read_layouts
		Dir[File.join(self.build_path, "layouts", "*")].entries.each do |layout_path|
			filename = File.basename(layout_path)
			unless filename =~ /\.html\.slim$/
				raise "Layout #{filename} does not appear to be a slim file"
			end

			template = Slim::Template.new(layout_path, :pretty => true)
			self.layouts[filename] = template
		end
	end

	def build_posts
		self.each_post do |pd|
			self.generate_post(pd)
		end
	end

	def build_styles
		sass_dir = Dir[File.join(self.build_path, "styles", "*")]
		sass_dir.entries.each do |source|
			source_path = File.expand_path(source)
			source_name = File.basename(source_path)

			next if source_name =~ /^_/

			out_name = source_name.gsub(/\.scss$/, '.css')
			out_name = out_name.gsub(/\.css\.css$/, '.css')
			out_path = File.join(self.site_path, 'css', out_name)

			css_path = File.join("/css", out_name)
			self.css_paths << css_path

			css = Sass.compile_file source_path
			File.open(out_path, 'w') do |f|
				f.write(css)
			end
		end
	end


	def clean_out_posts
		posts_path = File.join(self.site_path, "posts")
		%x{rm -f #{posts_path}/*}
	end

	def each_post(&block)
		dir = Dir[File.join(self.build_path, "posts", "*")]
		posts = dir.entries.map do |relpath|
			self.post_data(relpath)
		end.sort_by do |p|
			d = p[:date]
			[d.year, d.month, d.day]
		end

		posts.last[:out_name] = "index.html"
		posts.last[:out_path] = File.join(self.site_path, "index.html")
		posts.last[:site_path] = "/index.html"

		posts.each_with_index do |post, n|
			post[:prv] = n > 0 ? posts[n-1][:site_path] : nil
			post[:nxt] = n < posts.length-1 ? posts[n+1][:site_path] : nil
		end

		posts.each do |p|
			yield p
		end
	end

	def post_data(path)
		full_path = File.expand_path(path)
		file_name = File.basename(full_path)

		unless file_name =~ /\.md$/
			raise "Post #{file_name} does not appear to be markdown"
		end

		unless file_name =~ /^(\d+)\-(\d+)\-(\d+)\-([^\.]+)\.md$/
			raise "Post #{file_name} did not have a properly formatted name"
		end

		post_year = $1.to_i
		post_month = $2.to_i
		post_day = $3.to_i
		post_name = $4

		out_name = file_name.gsub(/\.md$/, '.html')

		date = Date.new(post_year, post_month, post_day)
		out_path = File.join(self.site_path, "posts", out_name)
		site_path = File.join("/posts", out_name)

		{ :full_path => full_path,
			:file_name => file_name,
			:post_name => post_name,
			:out_name  => out_name,
			:out_path  => out_path,
			:site_path => site_path,
			:date			 => date
		}
	end

	def generate_post(pd)
		post_layout = self.layouts['post.html.slim']

		metadata, markdown_content = parse_post(pd[:full_path])
		renderer = Redcarpet::Render::HTML.new
		parser = Redcarpet::Markdown.new(renderer)
		html_content = parser.render(markdown_content)

		html_post = post_layout.render(Object.new, {
				:title 		=> metadata[:title],
				:subtitle => metadata[:subtitle],
				:date 		=> pd[:date],
				:content 	=> html_content,
				:prv			=> pd[:prv],
				:nxt      => pd[:nxt]
			})

		site_layout = self.layouts['site.html.slim']
		html_page = site_layout.render(Object.new, {
			:title 			=> metadata[:title],
			:content 		=> html_post,
			:css_paths 	=> self.css_paths
			})


		File.open(pd[:out_path], 'w') do |f|
			f.write(html_page)
		end
	end

	def parse_post(path)
		contents = File.read(path)

		lines = contents.split("\n")
		meta_lines = lines.take_while{|l| l =~ /^\*\s/}
		lines.shift(meta_lines.length)

		props = {}
		meta_lines.each do |line|
			line = line.gsub(/^\*\s+/, '').strip
			key, sep, value = line.partition(':')
			key = key.strip.downcase.to_sym
			value = value.strip
			props[key] = value
		end

		content = lines.join("\n").strip

		[props, content]
	end

end
