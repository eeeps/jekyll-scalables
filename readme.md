# scalable-tag.rb

scalable-tag.rb and [scalables.js](https://github.com/eeeps/scalables), make inserting a responsive image into a Jekyll-powered site as easy as pointing to a full-resolution source file:

```
{% scalable /path/to/image.jpg alt="it's responsive!" %}
```

## dependencies

You'll need to be using [scalables.js](https://github.com/eeeps/scalables) and [Jekyll](http://jekyllrb.com/), of course.

Also you'll need to have [ImageMagick](http://www.imagemagick.org/).

## how?

Let's say that `/path/to/image.jpg` in the example above is 2048x1536.

Out of the box, scalable-tag.rb would generate the following files:

```
/path/to/image/half.jpg [1024x768]
/path/to/image/quarter.jpg [512x384]
/path/to/image/eighth.jpg [256x192]
/path/to/image/thumb.jpg [96x72]
/path/to/image/_info.yml
```

And the following markup:

```html
<div data-scalable>
	<img src="/path/to/image/thumb.jpg" data-width="96" data-height="72" alt="it's responsive!">
	<p>View image:</p>
	<ul>
		<li><a href="/path/to/image.jpg" data-width="2048" data-height="1536">fullsize (1.4 MB)</a></li>
		<li><a href="/path/to/image/half.jpg" data-width="1024" data-height="768">half (491 kB)</a></li>
		<li><a href="/path/to/image/quarter.jpg" data-width="512" data-height="384">quarter (149 kB)</a></li>
		<li><a href="/path/to/image/eighth.jpg" data-width="256" data-height="192">eighth (48 kB)</a></li>
	</ul>
</div>
```

…a completely portable chunk of plain-jane markup that scalables.js will progressively enhance, loading a reasonably-sized image for any user, through any viewport on any device, within any layout, without modification (woo).

Scalable-tag.rb uses ImageMagick to generate lower-resolution files by progressively halving the file's resolution until it reaches a pre-defined, global, thumbnail-max-dimension (96px by default).

## input paths

Jekyll doesn't like things other than posts in its `_posts` directory, which can make post-specific assets a pain.

So in addition to accepting absolute and relative paths, if the tag appears in a Jekyll post and references a relative path, scalable-tag.rb will look for the full-res image in a folder with the same name as the post, in a root-level 'assets' directory. For instance, if the following post …

```
/_posts/2013-07-13-lucky-thirteen.html
```

… contained the following tag …

```
{% scalable jackpot.jpg alt="Jackpot!" %}
```

`scalable-tag.rb` would look for the image here:

```
/assets/2013-07-13-lucky-thirteen/jackpot.jpg
```

## cacheing

scalable-tag.rb puts the generated, downsized images into a sub-directory with the same name as the image; it also sticks the paths, dimensions, and filesizes of these images into a sidecar `_info.yml` file in the same sub-directory.

Try not to touch the contents of this sub-folder. If you change anything about the source file, toss the whole thing to trigger a re-render.

