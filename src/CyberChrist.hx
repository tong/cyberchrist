
import Sys.print;
import Sys.println;
import sys.FileSystem;
import sys.io.File;
import haxe.Template;
import haxe.Timer;
import haxe.io.Path;
import om.Console;
import cyberchrist.Markup;

#if macro
import haxe.macro.Context;
#end

using StringTools;

//private typedef SyntaxFormatter = Format; // Markhaxe
//private typedef SyntaxFormatter = cyberchrist.Format; // Markhaxe

private typedef Config = {
	var url : String;
	var src : String;
	var dst : String;
	@:optional var title : String;
	@:optional var description : String;
	//@:optional var keywords : Array<String>
	@:optional var num_index_posts : Int; // num posts shown on index site
	@:optional var author : String;
	@:optional var img : String;
}

private typedef DateTime = {
	var year : Int;
	var month : Int;
	var day : Int;
	var utc : String;
	var datestring : String;
	//var pub : String;
}

private typedef Site = {
	var title : String;
	var date : DateTime;
	var content : String;
	var html : String;
	var layout : String;
	var css : Array<String>;
	var tags : Array<String>;
	var description : String;
	var author : String;
}

private typedef Post = { > Site,
	var id : String;
	var path : String;
	var keywords : String;
}

/*
	Cj8e2C|-|2!5† - Blog generator
*/
class CyberChrist {
	
	public static inline var VERSION = "0.3.2";
	public static var HELP(default,null) = buildHelp();
	public static inline var BUILD_INFO_FILE = '.cyberchrist';
	
	public static var cfg : Config = {
		url : "http://blog.disktree.net",
		src : "src/",
		dst : "out/",
		num_index_posts : 10,
		img : "/img/"
	};
	public static var siteTemplate : Template;
	public static var verbose = false;

	static var lastBuildDate : Float = -1;
	static var posts : Array<Post>;
	static var markup : Markup;

	static var e_site = ~/ *---(.+) *--- *(.+)/ms;
	static var e_header_line = ~/^ *([a-zA-Z0-9_\/\.\-]+) *: *([a-zA-Z0-9!_,\/\.\-\?\(\)\s]+) *$/;
	static var e_post_filename = ~/^([0-9][0-9][0-9][0-9])-([0-9][0-9])-([0-9][0-9])-([a-zA-Z0-9_,!\.\-\?\(\)\+]+)$/;

	/**
		Run cyberchrist on given source directory
	*/
	static function processDirectory( path : String ) {
		for( f in FileSystem.readDirectory( path ) ) {
			if( f.startsWith(".") )
				continue;
			var fp = path+f;
			if( FileSystem.isDirectory( fp ) ) {
				if( f.startsWith( "_" ) ) {
					//trace( "\t"+f );
					/*   
					switch( f.substr(1) ) {
					case "include":
						trace(" process include diectory" );
					//case "layout":
					case "posts":
						trace(" process posts");
					case "syndicate":
						trace(" process syndication" );
					default:
						warn( "Unkown cyberchrist directory ("+f+")" );
					}
					*/
				} else {
					var d = cfg.dst+f;
					if( !FileSystem.exists(d) ) FileSystem.createDirectory( d );
					//TODO not just copy file but process
					copyDirectory( f );
					//processDirectory(f);
				}
			} else {
				if( f.startsWith( "_" ) ) {
					// --- ignore files starting with an underscore
				} else if( f == "htaccess" ) {
					File.copy( fp, cfg.dst+'.htaccess' );
				} else {
					var ext = Path.extension( f );
					//println(ext);
					if( ext == null )
						continue;
					var ctx : Dynamic = createBaseContext();
					switch ext {
					case "xml","rss" :
						var tpl = new Template( File.getContent(fp) );
						var _posts : Array<Post> = ctx.posts;
						//for( p in _posts ) p.content = StringTools.htmlEscape( p.content );
						writeFile( cfg.dst+f, tpl.execute( ctx ) );
					case "html" :
						var site = parseSite( path, f );
						var tpl = new Template( site.content );
						var content = tpl.execute( ctx );
						ctx = createBaseContext();
						ctx.content = content;
						ctx.html = content;
						//trace(site.title);
						if( site.title != null ) ctx.title = site.title;
						if( site.description != null ) ctx.description = site.description;
						if( site.tags != null ) ctx.keywords = site.tags.join(",");
						writeHTMLSite( cfg.dst+f, ctx );
					case "less":
						println("LESSSSSS::::::::: "+fp+" :::: "+(cfg.dst+f) );
					default:
						File.copy( fp, cfg.dst+f );
					}
				}
			}
		}
	}

	/* //TODO use this method to process EVERY file
	static function processFile( p : String, f : String ) {
		if( f.startsWith( "_" ) ) {
			// --- ignore files starting with an underscore
			return;
		}
		var i = f.lastIndexOf(".");
		if( i == -1 ) {
			warn( 'unhandled file ($f)' );
		}
		var ext = f.substr( i+1 );
		var ctx : Dynamic = createBaseContext();
		switch( ext ) {
		case "xml","rss" :
			var tpl = new Template( File.getContent( p ) );
			var _posts : Array<Post> = ctx.posts;
			/*
			for( p in _posts ) {
				//p.content = StringTools.htmlEscape( p.content );
			}
			* /
			writeFile( cfg.dst+f, tpl.execute( ctx ) );
		case "html" :
			var site = parseSite( p, f );
			var tpl = new Template( site.content );
			var content = tpl.execute( ctx );
			ctx = createBaseContext();
			ctx.content = content;
			ctx.html = content;
			//trace(site.title);
			if( site.title != null ) ctx.title = site.title;
			if( site.description != null ) ctx.description = site.description;
			if( site.tags != null ) ctx.keywords = site.tags.join(",");
			writeHTMLSite( cfg.dst+f, ctx );
		case "less":
			//TODO less 2 css
			//lessc( fp, cfg.dst+f );
			trace("LESSSSSS::::::::: "+p+" :::: "+(cfg.dst+f) );
			File.copy( p, cfg.dst+f );

		//case "css" :
		//TODO do css compressions here
						//	File.copy( fp, path_dst+f );
		default:
			//TODO: check plugins .....
			File.copy( p, cfg.dst+f );
		}
	}
	*/
	
	/**
		Parse file at given path into a 'Site' object
	*/
	static function parseSite( path : String, name : String ) : Site {
		var fp = '$path/$name';
		var ft = File.getContent( fp );
		if( !e_site.match( ft ) )
			error( 'Invalid html template [$fp]' );
		var s : Site = cast {
			css : new Array<String>()
		};
		for( l in e_site.matched(1).trim().split("\n") ) {
			if( ( l = l.trim() ) == "" )
				continue;
			if( !e_header_line.match( l ) )
				error( "invalid template header ("+l+")" );
			var id = e_header_line.matched(1);
			var v = e_header_line.matched(2);
			switch( id ) {
			case "title": s.title = v;
			case "layout": s.layout = v;
			case "css": s.css.push(v);
			case "tags":
				s.tags = new Array();
				var tags = v.split( "," );
				for( t in tags ) s.tags.push( t.trim() );
			case "description": s.description = v;
			case "author": s.author = v;
			default : println( 'Unknown header key ($id)' );
			}
		}
		s.content = e_site.matched(2);
		return s;
	}
	
	/**
		Process/Print posts.
		@path The path to the post source
	*/
	static function printPosts( path : String ) {
		for( f in FileSystem.readDirectory( path ) ) {
			if( f.startsWith(".") )
				continue;
			if( !e_post_filename.match( f ) ) {
				//error( 'invalid filename for post [$f]' );
				warn( 'invalid filename for post [$f]' );
				continue;
			}
			// Create site object
			var site : Site = parseSite( path, f );
			if( site.layout == null )
				site.layout = "post";
			site.html = markup.format( site.content );
			var d_year = Std.parseInt( e_post_filename.matched(1) );
			var d_month = Std.parseInt( e_post_filename.matched(2) );
			var d_day = Std.parseInt( e_post_filename.matched(3) );
			var utc = formatUTC( d_year, d_month, d_day );
			var date : DateTime = {
				year : d_year,
				month : d_month,
				day : d_day,
				datestring : formatTimePart( d_year )+"-"+formatTimePart( d_month )+"-"+formatTimePart( d_day ),
				utc : utc,
			}
			var post : Post = {
				id : e_post_filename.matched(4),
				title : site.title,
				content : site.html,  //StringTools.htmlUnescape( site.content ), //site.content, //new Template( site.content ).execute( {} )
				html : site.html,
				layout : null,
				date : date,
				//tags : new Array<String>(),
				//description : (site.description==null) ? ((defaultSiteDescription==null)?null:defaultSiteDescription) : site.description,
				description : site.description,
				//author : site.author,
				author : (site.author==null) ? cfg.author : site.author,
				tags : site.tags, //["disktree","panzerkunst","art"],
				keywords : ( site.tags != null ) ? site.tags.join(",") : null,
				css : new Array<String>(),
				path : null
			};
			var path = cfg.dst + formatTimePart( d_year );
			if( !FileSystem.exists( path ) ) FileSystem.createDirectory( path );
			path = path+"/" + formatTimePart( d_month );
			if( !FileSystem.exists( path ) ) FileSystem.createDirectory( path );
			path = path+"/" + formatTimePart( d_day );
			if( !FileSystem.exists( path ) ) FileSystem.createDirectory( path );
			post.path =
				formatTimePart( d_year )+"/"+
				formatTimePart( d_month )+"/"+
				formatTimePart( d_day )+'/${post.id}.html';
			posts.push( post );
		}
		
		// Sort posts
		posts.sort( function(a,b){
			if( a.date.year > b.date.year ) return -1;
			else if( a.date.year < b.date.year ) return 1;
			else {
				if( a.date.month > b.date.month ) return -1;
				else if( a.date.month < b.date.month ) return 1;
				else {
					if( a.date.day > b.date.day ) return -1;
					else if( a.date.month < b.date.day ) return 1;
				}
			}
			return 0;
		});
		
		// Write post html files
		var tpl = parseSite( cfg.src+"_layout", "post.html" );
		print( 'Generating ${posts.length} posts : ' );
		for( p in posts ) {
			var ctx = mergeObjects( {}, p );
			ctx.content = new Template( tpl.content ).execute( p );
			writeHTMLSite( cfg.dst + p.path, ctx );
			Console.print( "+" );
		}
	}
	
	/**
		Create the base context for printing templates
	*/
	static function createBaseContext( ?attach : Dynamic ) : Dynamic {
		var _posts = posts;
		var _archive = new Array<Post>();
		if( cfg.num_index_posts > 0 && posts.length > cfg.num_index_posts ) {
			_archive = _posts.slice( cfg.num_index_posts );
			_posts = _posts.slice( 0, cfg.num_index_posts );
		}
		var n = Date.now();
		var dy = n.getFullYear();
		var dm = n.getMonth()+1;
		var dd = n.getDate();
		var now : DateTime = {
			year : dy,
			month : dm,
			day : dd,
			datestring : formatTimePart(dy)+"-"+formatTimePart(dm)+"-"+formatTimePart(dd),
			utc : formatUTC( dy, dm, dd )
		}
		var ctx = {
			title : cfg.title,
			url : cfg.url,
			posts : _posts,
			archive : _archive,
			description: cfg.description,
			now : now,
			cyberchrist_version : VERSION
			//keywords : ["disktree","panzerkunst","art"]
			//mobile:
			//useragent
		};
		if( attach != null )
			mergeObjects( ctx, attach );
		return ctx;
	}
	
	static function mergeObjects<A,B,R>( a : A, b : B ) : R {
		for( f in Reflect.fields( b ) ) Reflect.setField( a, f, Reflect.field( b, f ) );
		return cast a;
	}
	
	static inline function writeHTMLSite( path : String, ctx : Dynamic ) {
		var t = siteTemplate.execute( ctx );
		var a = new Array<String>();
		for( l in t.split( "\n" ) ) if( l.trim() != "" ) a.push(l);
		t = a.join( "\n" );
		writeFile( path, t );
	}
	
	static function formatUTC( year : Int, month : Int, day : Int ) : String {
		var s = new StringBuf();
		s.add( year );
		s.add( "-" );
		s.add( formatTimePart(month) );
		s.add( "-" );
		s.add( formatTimePart(day) );
		s.add( "T00:00:00Z" ); //TODO
		return s.toString();
	}

	static function formatUTCDate( d : Date ) : String {
		return formatUTC( d.getFullYear(), d.getMonth()+1, d.getDate() );
	}

	static function formatTimePart( i : Int ) : String {
		return if( i < 10 ) "0"+i else Std.string(i);
	}

	static function writeFile( path : String, content : String ) {
		var f = File.write( path, false );
		f.writeString( content );
		f.close();
	}
	
	static function clearDirectory( path : String ) {
		for( f in FileSystem.readDirectory( path ) ) {
			var p = path+"/"+f;
			if( FileSystem.isDirectory( p ) ) {
				clearDirectory( p );
				FileSystem.deleteDirectory( p );
			} else {
				FileSystem.deleteFile( p );
			}
		}
	}
	
	static function copyDirectory( path : String ) {
		var ps = cfg.src + path;
		for( f in FileSystem.readDirectory( ps ) ) {
			var s = '$ps/$f';
			var d = cfg.dst + '$path/$f';
			if( FileSystem.isDirectory( s ) ) {
				if( !FileSystem.exists(d) ) FileSystem.createDirectory( d );
				copyDirectory( '$path/$f' );
			} else {
				File.copy( s, d );
			}
		}
	}

	static function appendSlash( t : String ) : String return ( t.charAt( t.length ) != "/" ) ? t+"/" : t;

	static inline function warn( t : Dynamic ) Console.w( '  warning : '+t );

	static function error( info : Dynamic ) {
		Console.e( info );
		Sys.exit( 1 );
	}
	
	static function exit( ?info : Dynamic ) {
		if( info != null ) println( info );
		Sys.exit( 0 );
	}


	static function main() {

		var timestamp = Timer.stamp();

		var args = Sys.args();
		var cmd = args[0];
		if( cmd == null ) cmd = 'build';
		switch cmd {
		case "help": exit( HELP );
		case "version": exit( VERSION );
		}

		// Read/Parse config
		var path_cfg = 'src/_config'; //TODO
		if( FileSystem.exists( path_cfg ) ) {
			var ereg = ~/^([a-zA-Z0-9-]+) *([a-zA-Z0-9 .-_]+)$/;
			for( l in File.getContent( path_cfg ).split( '\n' ) ) {
				l = l.trim();
				var i = l.indexOf( "#" );
				if( i == 0 )
					continue;
				if( i != -1 )
					l = l.substr( 0, i );
				if( l.length == 0 )
					continue;
				if( ereg.match( l ) ) {
					var cmd = ereg.matched(1);
					var val = ereg.matched(2).trim();
					switch cmd {
					case "url" : cfg.url = val;
					case "src" : cfg.src = appendSlash( val );
					case "dst" : cfg.dst = appendSlash( val );
					case "title" : cfg.title = val;
					case "description", "desc" : cfg.description = val;
					case "img", "images" : cfg.img = val;
					case "nposts", "numposts" : cfg.num_index_posts = Std.parseInt( val );
					case "author" : cfg.author = val;
					//TODO: other config parameters
					//case "posts-shown" : cfg.post = val;
					//case "keywords" : cfg.url = val.split(''); //TODO regexp split
					//case "gist"
					default : warn( 'unknown configuration parameter [$cmd]' );
					}
				}
			}
		} else warn( 'no config file found' );

		// Check build requirements
		var requiredFiles = [
			cfg.src,
			//cfg.dst,
			cfg.src+'_layout',
			cfg.src+'_layout/site.html'
		];
		var errors = new Array<String>();
		for( f in requiredFiles )
			if( !FileSystem.exists( f ) )
				errors.push( 'missing file [${cfg.src}$f]' );
		if( errors.length > 0 ) {
			var m = new Array<String>();
			for( e in errors ) m.push( '  $e' );
			error( m.join('\n') );
		}

		if( FileSystem.exists( BUILD_INFO_FILE ) ) {
			lastBuildDate = Date.fromString( File.getContent( BUILD_INFO_FILE ) ).getTime();
		}

		switch cmd {
		case 'build':
			Console.i( 'cyberchrist > '+cfg.url );
			posts = new Array();
			markup = new Markup( {
				imagePath : cfg.img,
				createLink : function(s){return s;}
			} );
			siteTemplate = new Template( File.getContent( cfg.src+'_layout/site.html' ) );

			FileSystem.exists( cfg.dst ) ? clearDirectory( cfg.dst ) : FileSystem.createDirectory( cfg.dst );	

			printPosts( cfg.src+"_posts" ); // write posts
			processDirectory( cfg.src ); // Write everything else

			var fo = File.write( BUILD_INFO_FILE );
			fo.writeString( Date.now().toString() );
			fo.close();

			//Console.i( "\nok : "+Std.int((Timer.stamp()-timestamp)*1000)+"ms" );
			Console.i( '\nok : ${Std.int((Timer.stamp()-timestamp)*1000)}ms' );

		case 'clean' :
			if( FileSystem.exists( cfg.dst ) ) {
				clearDirectory( cfg.dst );
				FileSystem.deleteDirectory( cfg.dst );
				println( 'Cleaned' );
			}

		case 'config':
			Console.i( 'path : '+Sys.getCwd() );
			if( lastBuildDate != -1 )
				Console.i( 'Last build : '+Date.fromTime( lastBuildDate ) );
			else
				Console.i( 'Project not built' );
			for( f in Reflect.fields( cfg ) ) Console.i( '  $f : '+Reflect.field( cfg, f ) );
			exit();
		}
	}

	macro static function buildHelp() {
		var commands = [
		'build : Build project',
		'release : Build project in release mode',
		'clean : Remove all generated files',
		'config : Print project config',
		'help : Print this help',
		'version : Print cyberchrist version'
		].map( function(v){ return '    '+v; } ).join('\n');
  		return Context.makeExpr( 'Cyberchrist $VERSION
  Usage : cyberchrist <command>
  Commands :
${commands}', Context.currentPos() );
	}

}
