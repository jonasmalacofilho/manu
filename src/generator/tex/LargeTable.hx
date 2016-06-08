package generator.tex;

import transform.Document;

import Assertion.*;

class LargeTable {
	static inline var CHAR_COST = 1;
	static inline var SPACE_COST = 1;
	static inline var PAR_BREAK_COST = 10;
	static inline var LINE_BREAK_COST = 10;
	static inline var BULLET_COST = 1;
	static inline var FIG_MARK_COST = 10;
	static inline var TBL_MARK_COST = 10;
	static inline var BAD_COST = 1000;
	static inline var QUOTE_COST = 1;
	static inline var EM_DASH_COST = 2;
	static inline var NO_MODULES = 30;
	static inline var NO_MODULES_LARGE = 46;
	static inline var MIN_COLUMN = 4;
	static inline var SEPAR_SIZE = 1;

	static function pseudoHTypeset(h:HElem)
	{
		return switch h.def {
		case Wordspace: SPACE_COST;
		case Emphasis(i), Highlight(i): pseudoHTypeset(i);
		case Word(w): w.length;
		case HList(li):
			var cnt = 0;
			for (i in li)
				cnt += pseudoHTypeset(i);
			cnt;
		}
	}

	static function pseudoTypeset(v:TElem)
	{
		return switch v.def {
		case TLaTeXPreamble(_), THtmlApply(_): 0;
		case TVolume(_), TChapter(_), TSection(_), TSubSection(_), TSubSubSection(_): BAD_COST; // not allowed in tables
		case TVList(li):
			var cnt = 0;
			for (i in li) {
				cnt += pseudoTypeset(i);
				if (cnt > 0)
					cnt += PAR_BREAK_COST;
			}
			cnt;
		case TFigure(_, caption, cright, _): TBL_MARK_COST + pseudoHTypeset(caption) + SPACE_COST + pseudoHTypeset(cright);
		case TTable(_), TBox(_): BAD_COST; // not allowed (for now?)
		case TQuotation(text, by): QUOTE_COST + pseudoHTypeset(text) + QUOTE_COST + LINE_BREAK_COST + EM_DASH_COST + pseudoHTypeset(by);
		case TList(li):
			var cnt = 0;
			for (i in li) {
				cnt += BULLET_COST + SPACE_COST + pseudoTypeset(i);
				if (cnt > 0)
					cnt += LINE_BREAK_COST;
			}
			cnt;
		case TParagraph(h): pseudoHTypeset(h);
		}
	}

	// TODO document the objective and the implementation
	static function computeTableWidths(header, rows:Array<Array<TElem>>)
	{
		var width = header.length;
		var cost = header.map(pseudoTypeset);
		for (i in 0...rows.length) {
			var r = rows[i];
			if (r.length != width) continue;  // FIXME
			for (j in 0...width) {
				var c = r[j];
				cost[j] += pseudoTypeset(c);
			}
		}
		var tcost = Lambda.fold(cost, function (p,x) return p+x, 0);
		var available = NO_MODULES_LARGE - (width - 1)*SEPAR_SIZE;
		var ncost = cost.map(function (x) return available/tcost*x);
		for (i in 0...width) {
			if (ncost[i] < MIN_COLUMN)
				ncost[i] = MIN_COLUMN;
		}
		var icost = ncost.map(Math.round);
		var miss = available - Lambda.fold(icost, function (p,x) return p+x, 0);
		var priori = [for (i in 0...width) i];
		var diff = [for (i in 0...width) Math.abs(ncost[i] - icost[i])];
		priori.sort(function (a,b) return Reflect.compare(diff[b], diff[a]));
		var itCnt = 0;
		while (miss != 0 && itCnt++ < 4) {
			for (p in 0...width) {
				var i = priori[p];
				if (diff[i] == 0) continue;
				if (miss > 0) {
					icost[i]++;
					miss--;
				} else if (miss < 0) {
					if (icost[i] - 1 < MIN_COLUMN) continue;
					icost[i]--;
					miss++;
				} else {
					break;
				}
			}
		}
		var check = available - Lambda.fold(icost, function (p,x) return p+x, 0);
		assert(check == 0 && Lambda.foreach(icost, function (x) return x >= MIN_COLUMN), check, width, ncost, icost, priori, itCnt);
		return icost;
	}

	public static function gen(genAt:String, pos:Position, caption, header:Array<TElem>, rows:Array<Array<TElem>>, count:Int, id:String, gen:TexGen)
	{
		var colWidths = computeTableWidths(header, rows);
		var buf = new StringBuf();
		buf.add('% FIXME\nTable ${gen.genh(caption)}:\n\n');
		var width = header.length;
		buf.add('\\halign to ${NO_MODULES_LARGE}\\tablemodule{\\kern -49mm\n\t');
		for (i in 0...width) {
			if (i > 0)
				buf.add('\\hbox to ${SEPAR_SIZE*.5}\\tablemodule{}&\\hbox to ${SEPAR_SIZE*.5}\\tablemodule{}');
			var size = colWidths[i];
			buf.add('\\vtop{\\sffamily\\footnotesize\\noindent\\hsize=${size}\\tablemodule#}');
		}
		buf.add("\\cr\n\t");
		function genCell(i:TElem) {
			return switch i.def {
			case TParagraph(h): gen.genh(h);
			case _: gen.genv(i, genAt);
			}
		}
		buf.add(header.map(genCell).join("&"));
		buf.add("\\cr\n");
		for (r in rows) {
			weakAssert(r.length == width, header.length, r.length);
			buf.add("\t");
			if (r.length != width)
				buf.add("% ");  // FIXME
			buf.add(r.map(genCell).join("&"));
			buf.add("\\cr\n");
		}
		buf.add('}\n${gen.genp(pos)}\n');
		return buf.toString();
	}
}

