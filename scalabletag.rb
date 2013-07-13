module Jekyll
  
  # Thing to get at page.path from within a post... I took this from somehwere, forget where
    class PagePathGenerator < Generator
      safe true
      ## See post.dir and post.base for directory information. 
      def generate(site)
        site.posts.each do |post|
          post.data['path'] = post.name
        end
        
      end
    end
    
    class ScalableTag < Liquid::Tag
      
      
      # CONFIG
      
      
      @@jpeg_quality = 81
      @@thumb_longside = 96 # everybody loads the thumb so it's crucial to keep it small
      @@thumb_quality = 42 # and highly compressed
      
      
      # UTILITY BELT
      
      
      # the next power of 2 that dosen't end in 'th' is 8092, so just algorithmically generate the rest
      @@size_file_names = [ 'full', 'half', 'quarter', '8th', '16th', '32nd' ]
      
      
      # these are for <a> text in our html; above 1/32nd we algorithmically generate these with numeric fractions, instead of words, w/ <sup> + <sub> tags
      @@size_fancy_names = [ 'fullsize', 'half', 'quarter', 'eighth', 'sixteenth' ]
      
      
      def strip_extension(filename)        
        return filename.chomp( File.extname( filename ) )
      end
      
      
      def pretty_bytes( bytes )
        
        units = [ 'bytes', 'kB', 'MB', 'GB', 'TB', 'PB' ]
        x = ( Math.log(bytes) / Math.log(1000) ).to_i
        
        if ( x > units.length - 1 )
            x = units.length - 1
        end
        
        if (bytes == 0) # hopefully not, but...
            y = 0
            x = 0
        elsif ( x > 1 ) # add another digit of percision for big files
            y = ( 10 * bytes / 1000 ** x ).round.to_f / 10
        else 
            y = ( bytes / (1000 ** x).to_f ).round
        end
        
        return y.to_s + ' ' + units[x].to_s
        
      end
      
      
      def version_info(src)
        
        # [0] at the end makes sure we're only looking at first frame, animated gifs were causing trouble!
        raw = `identify -format "%G %b %m" #{ src + ( File.extname(src) == ".gif" ? "[0]" : "" ) }`
        
        # puts src
        # puts raw
        
        size = raw.split(' ')[0] # e.g. 200x100
        bytes = raw.split(' ')[1]
        format = raw.split(' ')[2]
        
        result = { "src" => src,
                         "width" => (size.split('x')[0]).to_i, 
                         "height" => (size.split('x')[1]).to_i, 
                         "bytes" => bytes.to_i,
                         "format" => format 
        }
        
        return result
        
      end
      
      
      def normalize_path(src_path)
        
        # set the @src_type and @path_from_root_to_src
        
        page_url = @page_object['url']        # url withouth the domain name (but with a leading slash), like:
                                              # /posts/2013/05/07/happy-birthday/index.html
                                              # /index.html (works for non-post pages, too)
                                              
        page_path = @page_object['path']      # name of the file in the _posts directory
                                              # 2013-05-07-happy-birthday.html
                                              # nil (for non-post pages)
        
        # ruby's backticked commands apparently run from a working directory of the site's root,
        # so to pass imagemagick usable paths, we need to remove the leading slash from the page_url.
        path_from_root_to_page_dir = File.dirname(page_url).sub(/^\//, '')
                                              # e.g. posts/2013/05/07/
        
        # as long as we're not in the root directory, add a trailing slash so that we can tack on filenames
        if path_from_root_to_page_dir != ""
          path_from_root_to_page_dir << "/"
        end
        
        # get the @src_type & use it to figure out the @path_to_root_from_src
        if src_path.split(//).first == '/' # if there's a leading slash
          return src_path[1..-1]
        else # if there's no leading slash
          if File.exists?(path_from_root_to_page_dir + src_path) # relative path
            return path_from_root_to_page_dir + src_path
          elsif !(@page_object['date'].nil?) # if this is a post, check the special asset directory
            return "assets/" + strip_extension( page_path.to_s ) + "/" + src_path
          else
            return nil
          end
        end
        
      end
      
      
      def resize_image_by_pct(file_in, resize_pct, file_out, other_switches = "")
        
        # file_in & file_out are relative paths from the site's root
        # resize_pct is a number between 1-100
        
        if !( File.exists?(file_out) )
                  
          # if we need a new directory, make it
          # maybe this go more than one level deep?
          destination_dir = File.dirname( file_out )
          Dir.mkdir( destination_dir ) unless File.directory?( destination_dir )
          
          # if it's a gif, only look convert the first frame
          `convert #{ file_in + ( File.extname(file_in) == ".gif" && File.extname(file_out) == ".jpg" ? "[0]" : "" ) } -resize #{ resize_pct.to_s }% #{other_switches} #{ file_out }`
          
          # this is poorly documented and took some trial and error to figure out
          # we need to add new files to this array, otherwise they won't get copied to the _site directory
          @site_object.static_files << StaticFile.new(
          
            # site - The Site.
            @site_object,
          
            # base - The String path to the <source>
            # source = ??? page dir? site's root? script's context? (what is that?)
            # it turns out it can be anything, as long as the dir gets us to the file from there?
            # perhaps it is supposed to be the same as the site's <source>?
            # in any case doing that aligns nicely with the paths we already have
            @site_object.source,
            # for future reference (?): puts @site_object.source -> /Users/portis/Sites/scalable_tag_test
          
            # dir - The String path between <source> and the file
            File.dirname( file_out ),
          
            # name - The String filename of the file
            File.basename( file_out )
          
          )
          
        end
        
      end
      
      
      # INITIALIZE
      
      
      def initialize(tag_name, text, tokens)
        
        super #duper
        
        # parse the input, which comes in the form
        # {% scalable path/to/src.jpg class="img-attributes" alt="go here" %}
        
        @src = text.split(' ')[0]
        # as with any html string path, src can be absolute (with a leading slash) or relative (with no leading slash) to the page's directory
        # if the tag is being used in a post, it can also be relative to a *special* directory we'll look for later, in the form of: /assets/[post-file-name]/ e.g. /assets/2013-05-07-happy-birthday/
        
        @leafname_no_extension = strip_extension( File.basename( @src ) );
        @ext = File.extname( @src );
        
        @attributes = " " + text.split(" ").drop(1).join(" ")
        
      end
      
      
      def get_info_and_make_versions
        
        
        # normalize src path
        # we take three different types of src path (relative, absolute, & special asset directory)
        # using the input src and info from the page object, normalize to a relative path from the root directory
        @path_from_root_to_src = normalize_path( @src )
        
        @path_from_root_to_generated_stuff = File.dirname( @path_from_root_to_src ) + "/" + strip_extension( File.basename( @src ) )
        generated_stuff_full_path = @site_object.source + "/" + @path_from_root_to_generated_stuff
        Dir.mkdir( generated_stuff_full_path ) unless File.directory?( generated_stuff_full_path )
        
        # read version info if it exists and skip the rest of this
        yaml_info_path = generated_stuff_full_path + '/_info.yml'
        
        if File.exists?( yaml_info_path )
          info = YAML.load( File.open( yaml_info_path ) )
          @thumb = info['thumb']
          @versions = info['versions']
          return
        end
        
        
        # MAKE VERSIONS
        
        
        # start versions array with fullsize image
        fullsize = version_info( @path_from_root_to_src )
        @versions = [ fullsize ]
        
        # we'll be needing this
        fullsize_longside = fullsize['width'] > fullsize['height'] ? fullsize['width'] : fullsize['height']
        
        # create thumb
        thumb_resize_pct = ( @@thumb_longside / fullsize_longside.to_f ) * 100
        
        # if it's a gif, it's probably animated, and we only want to make a jpg out of its first frame
        ext = ( @ext == ".gif" ? ".jpg" : @ext )
        
        path_from_root_to_thumb = strip_extension( @path_from_root_to_src ) + "/thumb" + ext
        
        # puts path_from_root_to_thumb
        
        # imagemagick seems to ignore any switches that don't make sense (quality on a png, for instance), yay
        resize_image_by_pct(@path_from_root_to_src, thumb_resize_pct, path_from_root_to_thumb, "-strip -interlace none -quality #{@@thumb_quality}%")
        
        @thumb = version_info( path_from_root_to_thumb )
        
        # create progressively halved versions between fullsize & thumb
        i = 1
        while fullsize_longside / ( 2 ** i ) > @@thumb_longside * 2 do
          
          resize_pct = 100 / ( 2 ** i ).to_f
          
          destination_basename = @@size_file_names[i] || ( 2**i ).to_s + 'th'
          destination_path = strip_extension( @path_from_root_to_src ) + "/" + destination_basename + @ext
          
          resize_image_by_pct(@path_from_root_to_src, resize_pct, destination_path, (fullsize['format'] == "JPEG" ? "-interlace plane -quality #{@@jpeg_quality}%" : "") )
          
          @versions.push( version_info( destination_path ) )
          
          
          i += 1
        end
        
        # save all this info so we don't have to do this work again
        f = File.open( yaml_info_path, 'w' )
        f.write({ 'thumb' => @thumb, 'versions' => @versions }.to_yaml)
        f.close
        
      end
      
      
      # RENDER
      
      
      def render(context)
        
        # puts @src
        
        # now that we have a context, store page and site objects
        # http://stackoverflow.com/questions/7478731/how-do-i-detect-the-current-page-in-a-jekyll-tag-plugin
      	@page_object = context.environments.first["page"]
        @site_object = context.registers[:site]
        
        get_info_and_make_versions
        
        # output html
        r = "<div id='#{ @leafname_no_extension }' data-scalable>\n" <<
            "\t<img src='#{ "/" << @thumb["src"] }' data-width='#{ @thumb["width"] }' data-height='#{ @thumb["height"] }'#{ @attributes } />\n" <<
            "\t<p>View image:</p>\n\t<ul>\n"
        
        @versions.each_with_index do |v, i|
          r << "\t\t<li><a href='#{ '/' << v["src"] }' data-width='#{ v["width"] }' data-height='#{ v["height"] }'>" <<
               (@@size_fancy_names[i] || "<sup>1</sup>&frasl;<sub>#{ (2 ** i).to_s }</sub>") <<
               " (" << pretty_bytes( v["bytes"] ) << ")" <<
               "</a></li>\n"
        end
        
        r << "\t</ul>\n</div>"
        
        # puts r
        
        return r
        
      end
      
    end
    
end

Liquid::Template.register_tag( 'scalable', Jekyll::ScalableTag )
