
import sys.FileSystem;
import sys.io.File;
import haxe.Template;
import haxe.Timer;
import om.Console;
#if macro
import haxe.macro.Context;
#end
using StringTools;

private typedef Config = {
	url : String,
	src : String,
	dst : String,
	title : String,
	description : String,
	//keywords : Array<String>
	num_posts : Int, // num posts shown on index site
	author : String,
	img : String
}

private typedef DateTime = {
	var year : Int;
	var month : Int;
	var day : Int;
	var utc : String;
	var datestring : String;
	//var pub : String;
}

//private typedef Page = {
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

/**
	Blog generator tool
*/
class CyberChrist {

	macro static function createHelp() {
		var commands = [
			'build : Build project',
			'release : Build project in release mode',
			'clean : Remove all generated files',
//			'edit : Open editor',
			'config : Print project config',
			'help : Print this help',
			'version : Print version'
		].map( function(v){ return '    '+v; } ).join('\n');
  		return Context.makeExpr( 'cyberchrist $VERSION
  Usage : cyberchrist <command>
${commands}', Context.currentPos() );
    }
	
	public static inline var VERSION = "0.3.1";
	public static var HELP(default,null) = createHelp();
	public static inline var BUILD_INFO_FILE = '.cyberchrist';
	
	public static var cfg : Config;
	public static var siteTemplate : Template;
	public static var verbose = false;

	static var lastBuildDate : Float = -1;
	static var posts : Array<Post>;
	static var wiki : Wiki;

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
					if( !FileSystem.exists(d) )
						FileSystem.createDirectory( d );
					copyDirectory( f );
				}
			} else {
				if( f.startsWith( "_" ) ) {
					// --- ignore files starting with an underscore
				} else if( f == "htaccess" ) {
					File.copy( fp, cfg.dst+'.htaccess' );
				} else {
					var i = f.lastIndexOf(".");
					if( i == -1 ) {
						continue;
					} else {
						var ext = f.substr( i+1 );
						var ctx : Dynamic = createBaseContext();
						switch( ext ) {
						case "xml","rss" :
							var tpl = new Template( File.getContent(fp) );
							var _posts : Array<Post> = ctx.posts;
							for( p in _posts ) {
								//p.content = StringTools.htmlEscape( p.content );
							}
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
						//case "css" :
						//TODO do css compressions here
						//	File.copy( fp, path_dst+f );
						default:
							//TODO: check plugins .....
							File.copy( fp, cfg.dst+f );
						}
					}
				}
			}
		}
	}
	
	/**
		Parse file at given path into a Site object
	*/
	static function parseSite( path : String, name : String ) : Site {
		var fp = path+"/"+name;
		var ft = File.getContent( fp );
		if( !e_site.match( ft ) )
			error( "invalid html template ("+fp+")" );
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
			case "title":
				s.title = v;
			case "layout":
				s.layout = v;
			case "css":
				s.css.push(v);
			case "tags":
				s.tags = new Array();
				var tags = v.split( "," );
				for( t in tags ) {
					s.tags.push( t.trim() );
				}
			case "description":
				s.description = v;
			case "author":
				s.author = v;
			default :
				println( "unknown header key ("+id+")" );
			}
		}
		//var s : Site = header;
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
			if( !e_post_filename.match( f ) )
				error( 'invalid filename for post [$f]' );
			
			// create site object
			var site : Site = parseSite( path, f );
			if( site.layout == null )
				site.layout = "post";
			
			site.html = wiki.format( site.content );
			
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
		
		// sort posts
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
		
		// --- write post html files
		var tpl = parseSite( cfg.src+"_layout", "post.html" );
		print( 'generating ${posts.length} posts : ' );
		for( p in posts ) {
			var ctx = mixContext( {}, p );
			ctx.content = new Template( tpl.content ).execute( p );
			writeHTMLSite( cfg.dst + p.path, ctx );
			Console.print( "+" );
		}
	}
	
	/**
		Create the base context for printing templates from anything.
	*/
	static function createBaseContext( ?attach : Dynamic ) : Dynamic {
		
		var _posts = posts;
		var _archive = new Array<Post>();
		if( posts.length > cfg.num_posts ) {
			_archive = _posts.slice( cfg.num_posts );
			_posts = _posts.slice( 0, cfg.num_posts );
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

		//TODO: default context
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
			mixContext( ctx, attach );
		return ctx;
	}
	
	static function mixContext<A,B,R>( a : A, b : B ) : R {
		for( f in Reflect.fields( b ) )
			Reflect.setField( a, f, Reflect.field( b, f ) );
		return cast a;
	}
	
	static inline function writeHTMLSite( path : String, ctx : Dynamic ) {
		var t = siteTemplate.execute( ctx );
		var a = new Array<String>();
		for( l in t.split( "\n" ) )
			if( l.trim() != "" ) a.push(l);
		t = a.join("\n");
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
		if( i < 10 ) {
			return "0"+i;
		}
		return Std.string(i);
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
			var s = ps + "/" + f;
			var d = cfg.dst + path + "/" + f;
			if( FileSystem.isDirectory( s ) ) {
				if( !FileSystem.exists(d) )
					FileSystem.createDirectory( d );
				copyDirectory( path+"/"+f );
			} else {
				File.copy( s, d );
			}
		}
	}

	static inline function print( t : Dynamic ) Sys.print(t);
	static inline function println( t : Dynamic ) Sys.println(t);
	static inline function warn( t : Dynamic ) {
		Console.w( '  warning : '+t );
	}

	static function error( ?m : Dynamic ) {
		if( m != null )
			Console.e( m );
		Sys.exit( 1 );
	}
	
	static function exit( ?v : Dynamic ) {
		if( v != null )
			println( v );
		Sys.exit( 0 );
	}

	static function appendSlash( t : String ) : String {
		return ( t.charAt( t.length ) != "/" ) ? t+"/" : t;
	}

	static function main() {
		
		var ts = Timer.stamp();

		var args = Sys.args();
		var cmd = args[0];
		if( cmd == null )
			cmd = 'build';
		switch( cmd ) {
		case "help":
			exit( HELP );
		case "version":
			exit( VERSION );
		}
	
		cfg = cast { // default config
			url : "http://blog.disktree.net",
			src : "src/",
			dst : "www/",
			num_posts : 10,
			img : "/img/"
		};

		// --- read config
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
					switch( cmd ) {
					case "url" : cfg.url = val;
					case "src" : cfg.src = appendSlash( val );
					case "dst" : cfg.dst = appendSlash( val );
					case "title" : cfg.title = val;
					case "description", "desc" : cfg.description = val;
					case "img", "images" : cfg.img = val;
					case "nposts", "numposts" : cfg.num_posts = Std.parseInt( val );
					case "author" : cfg.author = val;
					//TODO: other config parameters
					//case "posts-shown" : cfg.post = val;
					//case "keywords" : cfg.url = val.split(''); //TODO regexp split
					//case "gist"
					default :
						warn( 'unknown configuration parameter [$cmd]' );
					}
				}
			}
		} else {
			warn( 'no config file found' );
		}

		// --- check build requirements
		var requiredFiles = [
			cfg.src,
			//cfg.dst,
			cfg.src+'_layout',
			cfg.src+'_layout/site.html'
		];
		var errors = new Array<String>();
		for( f in requiredFiles ) {
			if( !FileSystem.exists( f ) )
				errors.push( 'missing file ${cfg.src}$f' );
		}
		if( errors.length > 0 ) {
			var m = new Array<String>();
			for( e in errors )
				m.push( '  $e' );
			error( m.join('\n') );
		}

		if( FileSystem.exists( BUILD_INFO_FILE ) ) {
			lastBuildDate = Date.fromString( File.getContent( BUILD_INFO_FILE ) ).getTime();
		}

		switch( cmd ) {
		
		case 'clean' :
			if( FileSystem.exists( cfg.dst ) ) {
				clearDirectory( cfg.dst );
				FileSystem.deleteDirectory( cfg.dst );
				println( 'project cleaned' );
			}

		case 'build':

			Console.i( 'cyberchrist > '+cfg.url );
			posts = new Array();
			wiki = new Wiki( {
				imagePath : cfg.img,
				createLink : function(s){return s;}
			} );
			siteTemplate = new Template( File.getContent( cfg.src+'_layout/site.html' ) );

			if( FileSystem.exists( BUILD_INFO_FILE ) ) {
				lastBuildDate = Date.fromString( File.getContent( BUILD_INFO_FILE ) ).getTime();
			}
			
			//TODO
			/*
			if( lastBuildDate > 0 ) {
				Console.d("ALREADY EXISTS");
			} else {

			}
			*/

			if( FileSystem.exists( cfg.dst ) ) {
				clearDirectory( cfg.dst ); // clear target directory
			} else {
				FileSystem.createDirectory( cfg.dst );	
			}

			printPosts( cfg.src+"_posts" ); // write posts
			processDirectory( cfg.src ); // write everything else

			var fo = File.write( BUILD_INFO_FILE );
			fo.writeString( Date.now().toString() );
			fo.close();

			Console.i( "\nok : "+Std.int((Timer.stamp()-ts)*1000)+"ms" );

		case 'config':
			Console.i( 'path : '+Sys.getCwd() );
			if( lastBuildDate != -1 )
				Console.i( 'last build : '+Date.fromTime( lastBuildDate ) );
			else
				Console.i( 'project never built so far' );
			for( f in Reflect.fields( cfg ) )
				Console.i( '  $f : '+Reflect.field( cfg, f ) );
			exit();
		}
	}
}
