require 'date'
require 'slim'
require 'redcarpet'

class Converter
	attr_accessor :build_path, :site_path, :layouts

	def initialize(opts={})
		self.build_path = opts[:build_path] || File.expand_path(File.basename(__FILE__) + "/..")
		self.site_path = opts[:site_path] || File.expand_path(build_path + "/..")
		self.layouts = {}
	end

	def build_site!
		self.read_layouts
		#self.build_index
		self.build_posts
		#self.build_styles
	end

	def read_layouts
		Dir[File.join(self.build_path, "layouts", "*")].entries.each do |layout_path|
			filename = File.basename(layout_path)
			unless filename =~ /\.html\.slim$/
				raise "Layout #{filename} does not appear to be a slim file"
			end

			template = Slim::Template.new(layout_path)
			self.layouts[filename] = template
		end
	end

	def build_index
	end

	def build_posts
		self.each_post do |pd|
			self.generate_post(pd)
		end
	end

	def build_styles
	end



	def each_post(&block)
		Dir[File.join(self.build_path, "posts", "*")].entries.each do |relpath|
			yield post_data(relpath)
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

		{ :full_path => full_path,
			:file_name => file_name,
			:post_name => post_name,
			:out_path  => out_path,
			:date			 => date
		}
	end

	def generate_post(post_data)
		layout = self.layouts['post.html.slim']

		markdown_content = File.read(post_data[:full_path])
		renderer = Redcarpet::Render::HTML.new
		parser = Redcarpet::Markdown.new(renderer)
		html_content = parser.render(markdown_content)

		html_page = layout.render(Object.new, {
				:title => 'TITLE HERE',
				:subtitle => 'SUBTITLE',
				:content => html_content
			})
		File.open(post_data[:out_path], 'w') do |f|
			f.write(html_page)
		end
	end

end