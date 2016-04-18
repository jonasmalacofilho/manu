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

