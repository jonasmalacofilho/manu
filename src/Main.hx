import Sys.*;
import haxe.CallStack;
import haxe.io.Path;
import sys.FileSystem;
using Literals;

class Main {
	public static var debug(default,null) = false;
	public static var version(default,null) = {
		commit : Version.getGitCommitHash().substr(0,7),
		fullCommit : Version.getGitCommitHash(),
		haxe : Version.getHaxeCompilerVersion(),
		runtime : #if neko "Neko" #elseif js "JS" #end,
		platform : Sys.systemName()
	}

	static inline var BANNER = "The Online BRT Planning Guide Tool";
	static var USAGE = "
		Usage:
		  obrt generate <input file> <output dir>
		  obrt --version
		  obrt --help".doctrim();
	static var BUILD_INFO = '
		OBRT tool for ${version.platform}/${version.runtime}
		Built from commit ${version.commit} with Haxe ${version.haxe}'.doctrim();

	static function generate(ipath, opath)
	{
		if (debug) println('The current working dir is: `${Sys.getCwd()}`');
		if (!FileSystem.exists(ipath)) throw 'File does not exist: $ipath';
		if (FileSystem.isDirectory(ipath)) throw 'Not a file: $ipath';

		var ast = parser.Parser.parse(ipath);

		var doc = transform.Transform.transform(ast);

		if (!FileSystem.exists(opath)) FileSystem.createDirectory(opath);
		if (!FileSystem.isDirectory(opath)) throw 'Not a directory: $opath';

		var hgen = new generator.HtmlGen(Path.join([opath, "html"]));
		hgen.generate(doc);

		var tgen = new generator.TexGen(Path.join([opath, "pdf"]));
		tgen.writeDocument(doc);
	}

	static function main()
	{
		print(BANNER + "\n\n");
		debug = Sys.getEnv("DEBUG") == "1";

		try {
			var args = Sys.args();
			if (debug) println('Arguments are: `${args.join("`, `")}`');
			switch args {
			case [cmd, ipath, opath] if (StringTools.startsWith("generate", cmd)):
				generate(ipath, opath);
			case ["--version"]:
				println(BUILD_INFO);
			case ["--help"]:
				println(USAGE);
			case _:
				println(USAGE);
				exit(1);
			}
		} catch (e:hxparse.UnexpectedChar) {
			if (debug) print("Lexer ");
			var lpos = e.pos.getLinePosition(byte.ByteData.ofBytes(sys.io.File.getBytes(e.pos.psource)));
			println('ERROR: Unexpected character `${e.char}`');
			print('  at ${e.pos.psource}, ');
			if (lpos.lineMin != lpos.lineMax)
				println('from (line=${lpos.lineMin}, byte=${lpos.posMin+1}) to (line=${lpos.lineMax}, byte=${lpos.posMax})');
			else if (lpos.posMin != lpos.posMax)
				println('line=${lpos.lineMin}, bytes=(${lpos.posMin+1} to ${lpos.posMax+1})');
			else 
				println('line=${lpos.lineMin+1}, byte=${lpos.posMin+1}');
			if (debug) println(CallStack.toString(CallStack.exceptionStack()));
			exit(2);
		} catch (e:parser.Error.GenericError) {
			if (debug) print("Parser ");
			var lpos = e.lpos;
			println('ERROR: ${e.text}');
			print('  at ${e.pos.src}, ');
			if (lpos.lines.min != lpos.lines.max - 1)
				println('from (line=${lpos.lines.min+1}, column=${lpos.codes.min+1}) to (line=${lpos.lines.max}, column=${lpos.codes.max})');
			else if (lpos.codes.min != lpos.codes.max - 1)
				println('line=${lpos.lines.min+1}, columns=(${lpos.codes.min+1} to ${lpos.codes.max})');
			else 
				println('line=${lpos.lines.min+1}, column=${lpos.codes.min+1}');
			if (debug) println(CallStack.toString(CallStack.exceptionStack()));
			exit(3);
		} catch (e:Dynamic) {
			if (debug) print("Untyped ");
			println('ERROR: $e');
			if (debug) println(CallStack.toString(CallStack.exceptionStack()));
			exit(9);
		}
	}
}

