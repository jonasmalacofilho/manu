import parser.*;
import parser.Token;
import utest.Assert;

class LexerTests {
	public function new() {}

	static function lex(s:String)
	{
		var tokens = [];
		var data = byte.ByteData.ofString(s);
		var lexer = new Lexer(data, "test");
		do {
			var tok = lexer.token(Lexer.tokens);
			tokens.push(tok);
			if (tok.def.match(TEof))
				break;
		} while (true);
		return tokens;
	}

	static function defs(s:String)
		return lex(s).map(function (t) return t.def);

	static function positions(s:String)
		return lex(s).map(function (t) return { min:t.pos.min, max:t.pos.max });

	public function test_000_startup()
	{
		Assert.same([TWord("foo"),TEof], defs("foo"));
	}

	public function test_001_basicWhitespace()
	{
		Assert.same([TWordSpace(" "),TEof], defs(" "));
		Assert.same([TWordSpace(" \t"),TEof], defs(" \t"));
		Assert.same([TWordSpace(" \n"),TEof], defs(" \n"));
		Assert.same([TWordSpace(" \r\n"),TEof], defs(" \r\n"));

		Assert.same([TWord("foo"),TWordSpace(" \n"),TWord("bar"),TWordSpace("\t\r\n"),TEof], defs("foo \nbar\t\r\n"));
		Assert.same([TWord("foo"),TBreakSpace(" \t\r\n\n"),TWord("bar"),TEof], defs("foo \t\r\n\nbar"));
	}

	public function test_002_comments()
	{
		// line comments
		Assert.same([TLineComment(" foo"),TEof], defs("// foo"));
		Assert.same([TWord("foo"),TWordSpace("  "),TLineComment(" bar"),TBreakSpace("\n\n"),TEof], defs("foo  // bar\n\n"));
		Assert.same([TLineComment("foo"),TWordSpace("\n"),TWord("bar"),TEof], defs("//foo\nbar"));

		// block comments
		Assert.same([TBlockComment(" foo "),TEof], defs("/* foo */"));
	}
	
	public function test_003_commands()
	{
		Assert.same([TCommand("foo"), TEof], defs("\\foo"));
		
		Assert.same([TCommand("section"), TWordSpace("\n"), TEof], defs("\\section\n"));
		
		Assert.same([TCommand("title"), TBrOpen, TWord("foo") , TBrClose, TEof], defs("\\title{foo}"));
		//Considering one whitespace
		Assert.same([TCommand("title"), TWordSpace(" "), TBrOpen, TWord("foo") , TBrClose, TEof], defs("\\title {foo}"));
		
		Assert.same([TCommand("foo"), TBrOpen, TWord("bar"), TBrClose, TBrkOpen, TWord("opt"), TBrkClose, TEof], defs("\\foo{bar}[opt]"));
		//Consideting one whitespace again
		Assert.same([TCommand("foo"), TBrOpen, TWord("bar"), TBrClose,TWordSpace(" "), TBrkOpen,  TWord("opt"), TBrkClose, TEof], defs("\\foo{bar} [opt]"));
	}
	
	public function test_004_fancies()
	{
		Assert.same([THashes(1), TWord("foo"), THashes(1), TEof], defs("#foo#"));
		
		Assert.same([THashes(1), TEof], defs("#"));
		Assert.same([THashes(3), TEof], defs("###"));
		
		Assert.same([THashes(3), TWordSpace(" "), TWord("Foo"), TEof], defs("### Foo"));
		Assert.same([THashes(3), TWord("Foo"), TEof], defs("###Foo"));
		Assert.same([THashes(1), TWord("Foo"), TEof], defs("#Foo"));
		Assert.same([TWord("Foo"),THashes(1), TEof], defs("Foo#"));
	}
	
	public function test_005_escapes()
	{
		Assert.same([TWord("\\"), TWord("foo"), TEof], defs("\\\\foo"));
		Assert.same([TWord("foo"),TWord("\\"), TEof], defs("foo\\"));
		
		Assert.same([TWord("#"), TWord("foo"), TEof], defs("\\#foo"));
		Assert.same([TWord("foo"), TWord("#"),  TEof], defs("foo\\#"));
		trace(defs("foo\\#"));
		trace(defs("foo\\\\"));
	}

	public function test_999_position()
	{
		Assert.same({ min:0, max:0 }, positions("")[0]);
		Assert.same({ min:0, max:1 }, positions(" ")[0]);
		Assert.same({ min:0, max:2 }, positions(" \t")[0]);
		Assert.same({ min:1, max:3 }, positions("a\n\n")[1]);
		Assert.same({ min:1, max:7 }, positions(" // foo\n")[1]);
		Assert.same({ min:0, max:9 }, positions("/* foo */")[0]);
	}
}

