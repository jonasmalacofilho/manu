import Sys.*;
import haxe.CallStack;
import haxe.io.Path;
import sys.FileSystem;

class Main {
	static inline var BANNER = "The Online BRT Planning Guide Tool\n\n";
	static inline var USAGE = "Usage: obrt generate <input file>\n";

	static function generate(path)
	{
		if (!FileSystem.exists(path)) throw 'File does not exist: $path';
		if (FileSystem.isDirectory(path)) throw 'Not a file: $path';

		var ast = parser.Parser.parse(path);

		var doc = transform.Transform.transform(ast);

		var hgen = new generator.HtmlGen(path + ".html");
		hgen.generate(doc);

		trace("TODO generate tex");
	}

	static function main()
	{
		print(BANNER);

		try {
			var args = Sys.args();
#if hxnodejs
			trace(Sys.args());
			args = args.slice(2);
			trace(args);
#end
			switch args {
			case [cmd, path] if (StringTools.startsWith("generate", cmd)):
				generate(path);
			case _:
				print(USAGE);
				exit(1);
			}
		} catch (e:Dynamic) {
			println('Error: $e');
			if (Sys.getEnv("DEBUG") == "1")
				println(CallStack.toString(CallStack.exceptionStack()));
			exit(2);
		}
	}
}

