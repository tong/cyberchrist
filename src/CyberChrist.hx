
import haxe.Timer;
import neko.Lib;
import neko.Sys;
import neko.FileSystem;
import neko.io.File;
import haxe.Template;

using StringTools;

private typedef Config = {
	url : String,
	src : String,
	dst : String,
	title : String,
	description : String,
	//keywords : Array<String>
	num_posts : Int, // num posts shown on index site
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
	Cyberchrist template fucker for blogs and shit.
	Holy moly!!
*/
class CyberChrist {
	
	public static inline var VERSION = "0.2.4";
	
	static var e_site = ~/ *---(.+) *--- *(.+)/ms;
	static var e_header_line = ~/^ *([a-zA-Z0-9_\/\.\-]+) *: *([a-zA-Z0-9!_,\/\.\-\?\(\)\s]+) *$/;
	static var e_post_filename = ~/^([0-9][0-9][0-9][0-9])-([0-9][0-9])-([0-9][0-9])-([a-zA-Z0-9_,!\.\-\?\(\)\+]+)$/;
	
	static var cfg : Config;
	static var tpl_site : Template;
	static var posts : Array<Post>;
	static var panda : Panda;
	
	// --------------- SYSTEM ---------------
	
	static inline function prnt( t : String ) Lib.print(t)
	static inline function print( t : String ) Lib.print(t)
	static inline function println( t : String ) Lib.println(t)
	static inline function warn( t : String ) println( "Warning! "+t )
	
	static function writeFile( path : String, t : String ) {
		var f = File.write( path, false );
		f.writeString( t );
		f.close();
	}
	
	static function clearDirectory( path : String ) {
		for( f in FileSystem.readDirectory( path ) ) {
			var p = path+"/"+f;
			/*
			switch( FileSystem.kind( p ) ) {
			case kdir :
				clearDirectory( p );
				FileSystem.deleteDirectory( p );
			case kfile :	
				FileSystem.deleteFile( p );
			default :
			}
			*/
			if( FileSystem.isDirectory( p ) ) {
				clearDirectory( p );
				FileSystem.deleteDirectory( p );
			} else {
				FileSystem.deleteFile( p );
			}
		}
	}
	
	static function copyDataDirectory( path : String ) {
		var ps = cfg.src + path;
		for( f in FileSystem.readDirectory( ps ) ) {
			var s = ps + "/" + f;
			var d = cfg.dst + path + "/" + f;
			if( FileSystem.isDirectory( s ) ) {
				if( !FileSystem.exists(d) )
					FileSystem.createDirectory( d );
				copyDataDirectory( path+"/"+f );
			} else {
				File.copy( s, d );
			}
		}
	}
	

	// --------------- SOURCE PROCESSING ---------------

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
						trace("TODO process include diectory" );
					//case "layout":
					case "posts":
						trace("TODO process posts");
					case "syndicate":
						trace("TODO process syndication" );
					default:
						warn( "Unkown cyberchrist directory ("+f+")" );
					}
					*/
				} else {
					var d = cfg.dst+f;
					if( !FileSystem.exists(d) )
						FileSystem.createDirectory( d );
					copyDataDirectory( f );
				}
			} else {
				if( f.startsWith( "_" ) ) {
					// ignore files starting with an underscore
				} else if( f == "htaccess" ) {
					// TODO: process htaccess file(s)
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
							
							//TODO check plugins .....

							File.copy( fp, cfg.dst+f );
						}
					}
				}
			}
		}
	}
	
	/**
		Parse file at given path into a cyberchrist.Site object
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
				trace( "unknown header key ("+id+")" );
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
				error( "invalid post filename ["+f+"]" );
			
			// create site object
			var site : Site = parseSite( path, f );
			if( site.layout == null )
				site.layout = "post";
			
			site.html = panda.format( site.content );
			
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
				author : site.author,
				//author : (site.author==null) ? defaultAuthor : site.author,
				
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
				formatTimePart( d_day )+"/"+post.id+".html";
			posts.push( post );
		}
		
		// sort posts
		posts.sort( function(a:Post,b:Post){
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
		
		// write posts html
		var tpl = parseSite( cfg.src+"_layout", "post.html" );
		prnt("Posts");
		for( p in posts ) {
			var ctx = mixContext( {}, p );
			ctx.content = new Template( tpl.content ).execute( p );
			writeHTMLSite( cfg.dst + p.path, ctx );
			prnt(".");
		}
		prnt("("+posts.length+")");
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
			title : cfg.title, //"blog.disktree.net",
			url : "http://blog.disktree.net",
			posts : _posts,
			archive : _archive,
			//description: "Panzerkunst motherfucker", //TODO
			//keywords : ["disktree","panzerkunst","art"]
			now : now,
			cyberchrist_version : VERSION
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
		var t = tpl_site.execute( ctx );
		var a = new Array<String>();
		for( l in t.split("\n") ) {
			if( l.trim() != "" ) a.push(l);
		}
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
	
	static function error( ?info : String ) {
		if( info != null ) println( "ERROR: "+info );
		Sys.exit(0);
	}

	static function appendSlash( t : String ) : String {
		return ( t.charAt( t.length ) != "/" ) ? t+"/" : t;
	}
	
	static function main() {
		
		println( "CyberChrist "+VERSION );
		
		//TODO read cl params
		//var args = Sys.args();
		//println( "######################### "+args );
		//....
		
		var ts_start = Timer.stamp();

		// --- default config
		cfg = cast {
			url : "http://blog.disktree.net",
			src : "src/",
			dst : "www/",
			num_posts : 10,
			img : "/img/"
		};

		// --- read config file
		var ereg = ~/^([a-zA-Z0-9-]+) *([a-zA-Z0-9 .-_]+)$/;
		var path_cfg = 'src/_config'; //TODO
		if( FileSystem.exists( path_cfg ) ) {
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
					//TODO: other config parameters
					//case "posts-shown" : cfg.post = val;
					//case "keywords" : cfg.url = val.split(''); //TODO regexp split
					//case "gist"
					default :
						println( "Unknown configuration parameter ["+cmd+"]" );
					}
				}
			}
		} else {
			println( 'No config file found, using default parameters' );
		}

		// --- test required files
		var requiredFiles = [
			cfg.src, cfg.dst,
			cfg.src+'_layout', cfg.src+'_layout/site.html'
		];
		var errors = new Array<String>();
		for( f in requiredFiles ) {
			if( !FileSystem.exists( f ) )
				errors.push( 'file missing:'+cfg.src+''+f+')' );
		}
		if( errors.length > 0 ) {
			println( "Holy shit! ERROR" );
			for( e in errors ) println( "\t"+e );
			Sys.exit(0);
		}
		
		///////////// --- build

		posts = new Array();
		
		// ---- prepeare panda content formatter
		panda = new Panda( {
			path_img : cfg.img,
			createLink : function(s){return s;}
		} );

		// ---- prepare templates
		tpl_site = new Template( File.getContent( cfg.src+'_layout/site.html' ) );
		
		// --- clear target directory
		clearDirectory( cfg.dst );
		
		// ---- write posts
		printPosts( cfg.src+"_posts" );

		// ---- write everything else
		processDirectory( cfg.src );
		
		println( "\nOK, "+Std.int((Timer.stamp()-ts_start)*1000)+"ms" );
	}

}
