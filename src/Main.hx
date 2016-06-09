import Sys.*;
import haxe.CallStack;
import haxe.io.Path;
import sys.FileSystem;

class Main {
	public static var debug(default,null) = false;

	static inline var BANNER = "The Online BRT Planning Guide Tool\n\n";
	static inline var USAGE = "Usage: obrt generate <input file>\n";

	static function generate(path)
	{
		if (debug) println('The current working dir is: `${Sys.getCwd()}`');
		if (!FileSystem.exists(path)) throw 'File does not exist: $path';
		if (FileSystem.isDirectory(path)) throw 'Not a file: $path';

		var ast = parser.Parser.parse(path);

		var doc = transform.Transform.transform(ast);

		var hgen = new generator.HtmlGen(path + ".html");
		hgen.generate(doc);

		var tgen = new generator.TexGen(path + ".pdf");
		tgen.writeDocument(doc);
	}

	static function main()
	{
		print(BANNER);
		debug = Sys.getEnv("DEBUG") == "1";

		try {
			var args = Sys.args();
			if (debug) println('Arguments are: `${args.join("`, `")}`');
			switch args {
			case [cmd, path] if (StringTools.startsWith("generate", cmd)):
				generate(path);
			case _:
				print(USAGE);
				exit(1);
			}
		} catch (e:hxparse.UnexpectedChar) {
			println('${e.pos}: $e');
			if (debug) println(CallStack.toString(CallStack.exceptionStack()));
			exit(2);
		} catch (e:parser.Error.GenericError) {
            var linpos = e.lpos;
            if (linpos.lines.min != linpos.lines.max)
                println('Error in file ${e.pos.src} from line ${linpos.lines.min} col ${linpos.chars.min+1} to line ${linpos.lines.max} col ${linpos.chars.max} ');
            else if (linpos.chars.min != linpos.chars.max)
                println('Error in file ${e.pos.src} line ${linpos.lines.min} from col ${linpos.chars.min+1} to col ${linpos.chars.max} ');
            else 
                println('Error in file ${e.pos.src} line ${linpos.lines.min} at col ${linpos.chars.min+1}');
            println(' --> ${e.text}');
			if (debug) println(CallStack.toString(CallStack.exceptionStack()));
			exit(3);
		} catch (e:Dynamic) {
			println('Error: $e');
			if (debug) println(CallStack.toString(CallStack.exceptionStack()));
			exit(9);
		}
	}
}

