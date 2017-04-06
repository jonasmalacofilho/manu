package tex;

import generator.tex.*;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import transform.NewDocument;
import transform.Context;
import util.sys.FsUtil;

import Assertion.*;

using Literals;
using StringTools;
using PositionTools;

class Generator {
	static var FILE_BANNER = '
	% The Online BRT Planning Guide
	%
	% DO NOT EDIT THIS FILE MANUALLY!
	%
	% This file has been automatically generated from its sources
	% using the OBRT tool:
	%  tool version: ${Main.version.commit}
	%  haxe version: ${Main.version.haxe}
	%  runtime: ${Main.version.runtime}
	%  platform: ${Main.version.platform}
	'.doctrim();  // TODO runtime version, sources version

	var hasher:AssetHasher;
	var destDir:String;
	var preamble:StringBuf;
	var bufs:Map<String,StringBuf>;

	static var texEscapes = ~/([{}\$&#\^_%~])/g;  // FIXME complete with LaTeX/Math

	static inline var ASSET_SUBDIR = "assets";

	function _saveAsset(at:Array<String>, src:String, size:BlobSize):String
	{
		var sdir =
			switch size {
			case MarginWidth: "mw";
			case TextWidth: "tw";
			case FullWidth: "fw";
			}
		var ldir = Path.join([ASSET_SUBDIR, sdir]);
		var dir = Path.join([destDir, ldir]);
		if (!FileSystem.exists(dir))
			FileSystem.createDirectory(dir);

		var ext = Path.extension(src).toLowerCase();
		var data = File.getBytes(src);
		var hash = hasher.hash(src, data);

		// TODO question: is the extension even neccessary?
		var name = ext != "" ? hash + "." + ext : hash;
		var dst = Path.join([dir, name]);
		File.saveBytes(dst, data);

		var lpath = Path.join([ldir, name]);
		if (~/windows/i.match(Sys.systemName()))
			lpath = lpath.replace("\\", "/");
		assert(lpath.indexOf(" ") < 0, lpath, "spaces are toxic in TeX paths");
		assert(lpath.indexOf(".") == lpath.lastIndexOf("."), lpath, "unprotected dots are toxic in TeX paths");
		weakAssert(!Path.isAbsolute(lpath), "absolute paths might be toxic in TeX paths");
		weakAssert(~/[a-z\/-]+/.match(lpath), lpath, "weird chars are dangerous in TeX paths");
		return lpath;
	}

	function saveAsset(at, src, size)
		return Context.time("tex generation (saveAsset)", _saveAsset.bind(at, src, size));

	public function gent(text:String, preserveSlashes=false)
	{
		return text.split("\\").map(
			function (safe) {
				var part = texEscapes.replace(safe, "\\$1");  // assumes texEscapes has 'g' flag
				if (preserveSlashes)
					return part;
				return part.replace("/", "\\slash\\hspace{0pt}");
			}
		).join("\\textbackslash{}");
	}

	public function genp(pos:Position)
	{
		if (Context.texNoPositions)
			return "";
		if (Context.debug) {
			var lpos = pos.toLinePosition();
			return '% @ ${lpos.src}: lines ${lpos.lines.min + 1}-${lpos.lines.max}: code points ${lpos.codes.min + 1}-${lpos.codes.max}\n';  // TODO slow, be careful!
		}
		return '% @ ${pos.src}: bytes ${pos.min + 1}-${pos.max}\n';
	}

	public function genh(h:HElem)
	{
		switch h.def {
		case Wordspace:
			return " ";
		case Superscript(h):
			return '\\textsuperscript{${genh(h)}}';
		case Subscript(h):
			return '\\textsubscript{${genh(h)}}';
		case Emphasis(h):
			return '\\emphasis{${genh(h)}}';
		case Highlight(h):
			return '\\highlight{${genh(h)}}';
		case Word(word):
			return gent(word);
		case InlineCode(code):
			return '\\code{${gent(code)}}';
		case Math(tex):
			return '$$$tex$$';
		case Url(address):
			return '\\url{${gent(address, true)}}';
		case HElemList(li):
			var buf = new StringBuf();
			for (i in li)
				buf.add(genh(i));
			return buf.toString();
		case HEmpty:
			return "";
		}
	}

	public function genv(v:DElem, at:Array<String>, idc:IdCtx)
	{
		assert(!Lambda.foreach(at, function (p) return p.endsWith(".tex")), at, "should not be anything but a directory");
		switch v.def {
		case DHtmlStore(_), DHtmlToHead(_):
			return "";
		case DLaTeXPreamble(_.toInputPath() => path):
			// TODO validate path (or has Transform done so?)
			preamble.add('% included from `$path`\n');
			preamble.add(genp(v.pos));
			preamble.add(File.getContent(path).trim());
			preamble.add("\n\n");
			return "";
		case DLaTeXExport(_.toInputPath() => src, _.toOutputPath(destDir) => dest):
			assert(FileSystem.isDirectory(destDir));
			FsUtil.copy(src, dest, Context.debug);
			return "";
		case DVolume(no, name, children):
			idc.volume = v.id.sure();
			var id = idc.join(true, ":", volume);
			var path = Path.join(at.concat([idc.volume+".tex"]));
			var dir = at.concat([idc.volume]);
			var buf = new StringBuf();
			bufs[path] = buf;
			buf.add("% This file is part of the\n");
			buf.add(FILE_BANNER);
			buf.add('\n\n\\volume{$no}{${genh(name)}}\n\\label{$id}\n${genp(v.pos)}\n${genv(children, dir, idc)}');
			return '\\input{$path}\n\n';
		case DChapter(no, name, children):
			idc.chapter = v.id.sure();
			var id = idc.join(true, ":", volume, chapter);
			var path = Path.join(at.concat([idc.chapter+".tex"]));
			var buf = new StringBuf();
			bufs[path] = buf;
			buf.add("% This file is part of the\n");
			buf.add(FILE_BANNER);
			buf.add('\n\n\\chapter{$no}{${genh(name)}}\n\\label{$id}\n${genp(v.pos)}\n${genv(children, at, idc)}');
			return '\\input{$path}\n\n';
		case DSection(no, name, children):
			idc.section = v.id.sure();
			var id = idc.join(true, ":", volume, chapter, section);
			return '\\section{$no}{${genh(name)}}\n\\label{$id}\n${genp(v.pos)}\n${genv(children, at, idc)}';
		case DSubSection(no, name, children):
			idc.subSection = v.id.sure();
			var id = idc.join(true, ":", volume, chapter, section, subSection);
			return '\\subsection{$no}{${genh(name)}}\n\\label{$id}\n${genp(v.pos)}\n${genv(children, at, idc)}';
		case DSubSubSection(no, name, children):
			idc.subSubSection = v.id.sure();
			var id = idc.join(true, ":", volume, chapter, section, subSection, subSubSection);
			return '\\subsubsection{$no}{${genh(name)}}\n\\label{$id}\n${genp(v.pos)}\n${genv(children, at, idc)}';
		case DBox(no, name, children):
			idc.box = v.id.sure();
			var id = idc.join(true, ":", chapter, box);
			return '\\beginbox{$no}{${genh(name)}}\n\\label{$id}\n${genv(children, at, idc)}\\endbox\n${genp(v.pos)}\n';
		case DTitle(name):
			// FIXME optional id
			return '\\manutitle{${genh(name)}}\n${genp(v.pos)}\n';
		case DFigure(no, size, _.toInputPath() => path, caption, cright):
			idc.figure = v.id.sure();
			var id = idc.join(true, ":", chapter, figure);
			path = saveAsset(at, path, size);
			var csize =
				switch size {
				case MarginWidth: "small";
				case TextWidth: "medium";
				case FullWidth: "large";
				}
			// FIXME label
			return '\\manu${csize}figure{$path}{$no}{${genh(caption)}\\label{${id}}}{${genh(cright)}}\n${genp(v.pos)}\n';
		case DTable(_):
			idc.table = v.id.sure();
			var id = idc.join(true, ":", chapter, table);
			return LargeTable.gen(v, id, this, at, idc);
		case DImgTable(no, size, caption, _.toInputPath() => path):
			idc.table = v.id.sure();
			var id = idc.join(true, ":", chapter, table);
			path = saveAsset(at, path, size);
			var csize =
				switch size {
				case MarginWidth: "small";
				case TextWidth: "medium";
				case FullWidth: "large";
				}
			// FIXME label
			return '\\manu${csize}imgtable{$path}{$no}{${genh(caption)}\\label{${id}}}\n${genp(v.pos)}\n';
		case DList(numbered, li):
			var buf = new StringBuf();
			var env = numbered ? "enumerate" : "itemize";
			buf.add('\\begin{$env}\n');
			for (i in li)
				switch i.def {
				case DParagraph(h):
					buf.add('\\item ${genh(h)}${genp(i.pos)}');
				case _:
					buf.add('\\item {${genv(i, at, idc)}}\n');
				}
			buf.add('\\end{$env}\n');
			buf.add(genp(v.pos));
			buf.add("\n");
			return buf.toString();
		case DCodeBlock(code):
			show("code blocks in TeX improperly implemented");
			return '\\begincode\n${gent(code)}\n\\endcode\n${genp(v.pos)}\n';
		case DQuotation(text, by):
			return '\\quotation{${genh(text)}}{${genh(by)}}\n${genp(v.pos)}\n';
		case DParagraph({pos:p, def:Math(tex)}):
			return '\\[$tex\\]';
		case DParagraph(h):
			return '${genh(h)}\\par\n${genp(v.pos)}\n';
		case DElemList(li):
			var buf = new StringBuf();
			for (i in li)
				buf.add(genv(i, at, idc));
			return buf.toString();
		case DEmpty:
			return "";
		}
	}

	public function writeDocument(doc:NewDocument)
	{
		FileSystem.createDirectory(destDir);
		preamble = new StringBuf();
		preamble.add(FILE_BANNER);
		preamble.add("\n\n");

		var idc = new IdCtx();
		var contents = genv(doc, ["./"], idc);

		var root = new StringBuf();
		root.add(preamble.toString());
		root.add("\\begin{document}\n\n");
		root.add(contents);
		root.add("\\end{document}\n");
		bufs["book.tex"] = root;

		for (p in bufs.keys()) {
			var path = Path.join([destDir, p]);
			FileSystem.createDirectory(Path.directory(path));
			File.saveContent(path, bufs[p].toString());
		}
	}

	public function new(hasher, destDir)
	{
		this.hasher = hasher;
		// TODO validate destDir
		this.destDir = destDir;
		bufs = new Map();
	}
}

