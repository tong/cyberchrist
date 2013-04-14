
#if sys
import sys.io.File;
#end

using StringTools;

//TODO move to om.format.Wiki

typedef WikiConfig = {

	/** Path to the image directory */
	var imagePath : String;

	/** Callback for creating links */
	var createLink : String->String;

}

class Wiki {
	
	//static var div_open = ~/^\[([A-Za-z0-9_ ]+)\]$/;
	//static var div_close = ~/^\[\/([A-Za-z0-9_ ]+)\]$/;

	static var E_h1 = ~/====== ?(.*?) ?======/g;
	static var E_h2 = ~/===== ?(.*?) ?=====/g;
	static var E_h3 = ~/==== ?(.*?) ?====/g;
	static var E_h4 = ~/=== ?(.*?) ?===/g;
	static var E_h5 = ~/== ?(.*?) ?==/g;
	
	static var E_http_title = ~/\[\[(https?:[^\]"]*?)\|(.*?)\]\]/g;
	static var E_http = ~/\[\[(https?:[^\]"]*?)\]\]/g;
	//static var E_http_internal = ~/\[\[([a-zA-Z0-9_% ]*?)\]\]/g;
	//static var E_http_internal_title = ~/\[\[([a-zA-Z0-9_% ]*?)\|(.*?)\]\]/g;
	
	static var E_jid = ~/xmpp:([A-Z0-9._%-]+@[A-Z0-9.-]+\.[A-Z][A-Z][A-Z]?)/gi;
	
	static var E_img = ~/@([ A-Za-z0-9._-]+)@/g;
	static var E_img_withtitle = ~/@([ A-Za-z0-9._-]+)\|(.*?)@/g;
	
	static var E_file_absolute_title = ~/\{\{(https?:[^\]"]*?)\|(.*?)\}\}/;
	static var E_file_absolute = ~/\{\{(https?:[^\]"]*?)\}\}/;
	static var E_file = ~/\{\{([ A-Za-z0-9_\.\-\/]+)(|.*?)\}\}/;
		
	static var E_bold = ~/\*\*([^<>]*?)(\*\*)/g;
	static var E_italic = ~/\/\/([^<>]*?)(\/\/)/g;
	static var E_superscript = ~/\^\^([^<>]*?)\^\^/g;
	static var E_subscript = ~/,,([^<>]*?),,/g;
	static var E_strikeout = ~/~~([^<>]*?)~~/g;
	
	public var config : WikiConfig;
	//public var ext : Array<Formatter>;

	public function new( config : WikiConfig ) {
		this.config = config;
		//ext = new Array();
	}
	
	public function format( t : String ) : String {
		
		// --- remove multiline comments
		t = removeComments( t );

		t = ~/\r\n?/g.replace( t, "\n" );

		var me = this;
		var b = new StringBuf();
		
		var codes = new Array();
		t = ~/<code( [a-zA-Z0-9]+)?>([^\0]*?)<\/code>/.map(t,function(r) {
			var style = r.matched(1);
			var code = me.code(r.matched(2),isEmpty(style)?null:style.substr(1));
			codes.push(code);
			return "##CODE"+(codes.length-1)+"##";
		});
		
		var div_begin = ~/^\[(\/?[A-Za-z0-9_ ]+)\]/;
		var div_end = ~/\[(\/?[A-Za-z0-9_ ]+)\]$/;
		var pstack = new Array();
		for( t in ~/\n[ \t]*\n/g.split(t) ) {
			var p = formatParagraph(t);
			var after = "\n";
			while( div_begin.match(p) ) {
				var cl = div_begin.matched(1);
				if( cl.charAt(0) == "/" ) {
					cl = cl.substr(1);
					while( pstack.length > 0 ) {
						b.add("</div>");
						if( pstack.pop() == cl )
							break;
					}
				} else {
					pstack.push(cl);
					b.add( '<div class="$cl">' );
				}
				p = div_begin.matchedRight();
			}
			while( div_end.match(p) ) {
				var cl = div_end.matched(1);
				if( cl.charAt(0) == "/" ) {
					cl = cl.substr(1);
					while( pstack.length > 0 ) {
						after += "</div>";
						if( pstack.pop() == cl )
							break;
					}
				} else {
					pstack.push( cl );
					after += '<div class="$cl">';
				}
				p = div_end.matchedLeft();
			}
			switch( p.substr(0,3) ) {
			case "","<h1","<h2","<h3","<ul","<pr","##C","<sp":
				b.add(p);
			default:
				b.add("<p>");
				b.add(p);
				b.add("</p>");
			}
			b.add(after);
		}
		for( d in pstack )
			b.add( "</div>" );
		t = b.toString();

		// --- cleanup
		t = StringTools.replace(t, "<p><br/>", "<p>");
		t = StringTools.replace(t, "<br/></p>", "</p>");
		t = StringTools.replace(t, "<p></p>", "");
		t = StringTools.replace(t, "><p>", ">\n<p>");

		// --- code
		for( i in 0...codes.length ) {
			t = StringTools.replace( t, "##CODE"+i+"##", codes[i] );
		}

		return t;
	}

	public function formatParagraph( t : String ) : String  {

		// unhtml
		//t = StringTools.htmlEscape(t).split('"').join( "&quot;" );

		// span
		t = makeSpans(t);
		
		// newlines
		t = StringTools.replace( t,"\n","<br/>" );

		// force linebreak
		//t = StringTools.replace( t, "\\\\", "<br/>" );

		// ruler
		t = StringTools.replace( t, "----", "<hr>" );

		// h1-h5
		t = E_h1.replace( t, '<h1>$1</h1>' );
		t = E_h2.replace( t, '<h2>$1</h2>' );
		t = E_h3.replace( t, '<h3>$1</h3>' );
		t = E_h4.replace( t, '<h4>$1</h4>' );
		t = E_h5.replace( t, '<h5>$1</h5>' );
		
		// http link with custom title
		t = E_http_title.replace( t, '<a href="$1" class="extern">$2</a>' );
		// http link
		t = E_http.replace( t, '<a href="$1" class="extern">$1</a>' );
		// internal link
//		t = E_http_internal.replace( t, '<a href="'+config.createLink('$1')+'" class="intern">$1</a>' );
		// internal link with custom title
//		t = E_http_internal_title.replace( t, '<a href="'+config.createLink('$1')+'" class="intern">$2</a>' );

		// jid
		t = E_jid.replace( t, '<span class="xmpp">$1</span>' );

		// img
		var imagePath = config.imagePath;
		t = E_img.replace( t, '<img src="$imagePath$1" alt="$1"/>' );
		t = E_img.replace( t, '<img src="config.imagePath$1" alt="$1"/>' );
		t = E_img_withtitle.replace( t, '<a href="$2"><img src="config.path_img$1" alt="$1"/></a>' );
		
		// files with absolut path and title
		t = ~/\{\{(https?:[^\]"]*?)\|(.*?)\}\}/.map( t, function(r) {
			var link = r.matched( 1 );
			var title = r.matched( 2 );
			if( title == null || title == "" ) title = link;
			var ext = link.split(".").pop();
			return '<a href="$link" class="file file_$ext">$title</a>';
		} );

		// files with absolut path
		t = ~/\{\{(https?:[^\]"]*?)\}\}/.map( t, function(r) {
			var link = r.matched( 1 );
			var ext = link.split(".").pop();
			return '<a href="$link" class="file file_$ext">$link</a>';
		} );

		// files
		//t = ~/\{\{([ A-Za-z0-9._-]+)(|.*?)\}\}/.map(t,function(r) {
		t = ~/\{\{([ A-Za-z0-9_\.\-\/]+)(|.*?)\}\}/.map(t,function(r) {
			var link = r.matched(1);
			var title = r.matched(2);
			if( title == null || title == "" ) title = link else title = title.substr(1);
			var ext = link.split(".").pop();
			return '<a href="/files/$link" class="file file_$ext">$title</a>';
		} );

		// lists
		t = u_list( t );
		//t = o_list( t );

		// github-gists
		//TODO embedd js to load a gist
		//t = E_img.replace( t, '<img src="'+config.path_img+'$1" alt="$1"/>' );
		//static var E_img = ~/@([ A-Za-z0-9._-]+)@/g;

		// text
		t = E_italic.replace( t, '<em>$1</em>' );
		t = E_bold.replace( t, '<strong>$1</strong>' );
		t = E_superscript.replace( t, '<sup>$1</sup>' );
		t = E_subscript.replace( t, '<sub>$1</sub>' );
		t = E_strikeout.replace( t, '<span style="text-decoration:line-through;">$1</span>' );
		
		return t;
	}

	public function code( t : String, ?style : String ) : String {
		var cl = (style == null) ? '' : ' class="'+style+'"';
		if( t.charAt(0) == "\n" ) t = t.substr(1);
		if( t.charAt(t.length-1) == "\n" ) t = t.substr(0,t.length - 1);
		t = StringTools.replace(t,"\t","    ");
		t = StringTools.htmlEscape(t);
		switch( style ) {
		case "xml", "html":
			var me = this;
			t = ~/(&lt;\/?)([a-zA-Z0-9:_]+)([^&]*?)(\/?&gt;)/.map(t,function(r) {
				var tag = r.matched(2);
				var attr = ~/([a-zA-Z0-9:_]+)="([^"]*?)"/g.replace(r.matched(3),'<span class="att">$1</span><span class="kwd">=</span><span class="string">"$2"</span>');
				return '<span class="kwd">'+r.matched(1)+'</span><span class="tag">'+tag+'</span>'+attr+'<span class="kwd">'+r.matched(4)+'</span>';
			});
			t = ~/(&lt;!--(.*?)--&gt;)/g.replace(t,'<span class="comment">$1</span>');
		case "haxe":
			var tags = new Array();
			var untag = function(s,html) {
				return ~/##TAG([0-9]+)##/.map(s,function(r) {
					var t = tags[Std.parseInt(r.matched(1))];
					return html ? t.html : t.old;
				});
			}
			var tag = function(c,s) {
				tags.push({ old : s, html : '<span class="'+c+'">'+untag(s,false)+'</span>' });
				return "##TAG"+(tags.length-1)+"##";
			};
			t = ~/\/\*((.|\n)*?)\*\//.map(t,function(r) {
				return tag("comment",r.matched(0));
			});
			t = ~/"(\\"|[^"])*?"/.map(t,function(r) {
				return tag("string",r.matched(0));
			});
			t = ~/'(\\'|[^'])*?'/.map(t,function(r) {
				return tag("string",r.matched(0));
			});
			t = ~/\/\/[^\n]*/.map(t,function(r) {
				return tag("comment",r.matched(0));
			});
			var kwds = [
				"function","class","var","if","else","while","do","for","break","continue","return",
				"extends","implements","import","switch","case","default","static","public","private",
				"try","catch","new","this","throw","extern","enum","in","interface","untyped","cast",
				"override","typedef","dynamic","package","callback","inline","using","macro"
			];
			var types = [
				"Array","Bool","Class","Date","DateTools","Dynamic","Enum","Float","Hash","Int",
				"IntHash","IntIter","Iterable","Iterator","Lambda","List","Math","Null","Reflect",
				"Std","String","StringBuf","StringTools","Type","Void","Xml",
			];
			t = new EReg( "\\b("+kwds.join("|")+")\\b","g").replace( t, '<span class="kwd">$1</span>');
			t = new EReg( "\\b("+types.join("|")+")\\b","g").replace( t, '<span class="type">$1</span>');
			t = ~/\b([0-9.]+)\b/g.replace( t, '<span class="number">$1</span>' );
			t = ~/([{}\[\]()])/g.replace( t, '<span class="op">$1</span>' );
			t = untag( t, true );
		/*
		case "raw":
			if( config.allowRaw )
				return StringTools.htmlUnescape(t);
		*/
		default:
		}
		//return '<pre'+cl+'>'+t+"</pre>";
		return '<pre $cl>$t</pre>';
	}

	function removeComments( t : String ) {
		var i1 = t.indexOf( "/**" );
		if( i1 == -1 )
			return t;
		var t2 = t.substr( i1 );
		var i2 = t2.indexOf( "**/" );
		if( i2 != -1 ) {
			return t.substr( 0, i1 ) + removeComments( t2.substr( i2+3 ) );
		}
		return t;
	}
	
	function u_list( t : String ) : String {
		var r = ~/(^|<br\/>)([ \t]+)\* /;
		if( !r.match(t) )
			return t;
		var b = new StringBuf();
		var spaces = r.matched(2);
		var pos = r.matchedPos();
		b.addSub( t, 0, pos.pos );
		t = t.substr( pos.pos + pos.len );
		b.add( "<ul>" );
		for( x in new EReg( '<br/>$spaces\\* ', "g" ).split(t) )
			b.add( "<li>"+u_list(x)+"</li>" );
		b.add("</ul>");
		return b.toString();
	}
	
	/*
	function o_list( t : String ) : String {
		var r = ~/(^|<br\/>)([ \t]+)\- /;
		if( !r.match(t) )
			return t;
		var b = new StringBuf();
		var spaces = r.matched(2);
		var pos = r.matchedPos();
		b.addSub( t, 0, pos.pos );
		t = t.substr(pos.pos + pos.len);
		b.add("<ol>");
		for( x in new EReg("<br/>"+spaces+"\\- ","g").split(t) )
			b.add("<li>"+o_list(x)+"</li>");
		b.add("</ol>");
		return b.toString();
	}
	*/
	
	static inline function isEmpty(s) : Bool {
		// empty string is for neko <= 1.7.0 compatibility
		//return #if neko s == "" || s == null #else s == null #end;
		return s == null;
	}
	
	static function makeSpans( t : String ) : String {
		return ~/\n*\[([A-Za-z0-9_ ]+)\]\n*([^<>]*?)\n*\[\/\1\]\n*/.map( t, function(r) {
			return '<span class="'+r.matched(1)+'">'+makeSpans(r.matched(2))+'</span>';
		} );
	}
}
