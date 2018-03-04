module calc.parser;
import pegged.grammar;
import calc.vm;
import std.stdio,
       std.conv;

mixin(grammar(`
Calc:
  Term < Factor (Add / Sub)*
  Add < "+" Factor
  Sub < "-" Factor
  Factor < Primary (Mul / Div / Mod)*
  Mul < "*" Factor
  Div < "/" Factor
  Mod < "%" Factor

  Primary < Parens / Func / PowerExpr / Number

  Parens < :"(" Term :")"

  Func < Identifier ParameterList
  ParameterList < "()" / :"(" Parameter ("," Parameter)* :")"
  Parameter < Primary
  Identifier <~ [a-zA-Z_] [a-zA-Z0-9_]*

  PowerExpr < Number "^" Integer

  Number < Floating / Integer
  Integer <~ Sign? digit+
  Floating <~ Sign? [0-9]+ "." [0-9]+
  Sign <- "-" / "+"
`));

StackValue[string] funcs;
enum Identifiers = [
  "sqrt" : function Func ()  { return sqrt; },
  "square" : function Func () { return square; } 
];

static this() {
  foreach (key; Identifiers.keys) {
    funcs[key] = Identifiers[key]();
  }
}

StackValue[] buildCode(ParseTree p) {
  final switch (p.name) {
    case "Calc":
    case "Calc.Primary":
    case "Calc.Parens":
    case "Calc.Parameter":
      return buildCode(p.children[0]);
    case "Calc.Term":
    case "Calc.Factor":
      auto e = p.children[0];
      if (p.children.length == 1) { return buildCode(e); }
      auto e2 = p.children[1];
      return buildCode(e) ~ buildCode(e2);
    case "Calc.Add":
      return buildCode(p.children[0]) ~ cast(StackValue[])[iadd];
    case "Calc.Sub":
      return buildCode(p.children[0]) ~ cast(StackValue[])[isub];
    case "Calc.Mul":
      return buildCode(p.children[0]) ~ cast(StackValue[])[imul];
    case "Calc.Div":
      return buildCode(p.children[0]) ~ cast(StackValue[])[idiv];
    case "Calc.Mod":
      return buildCode(p.children[0]) ~ cast(StackValue[])[imod];
    case "Calc.Number":
      return buildCode(p.children[0]);
    case "Calc.Integer":
      return cast(StackValue[])[bipush] ~ cast(StackValue[])[integer(p.matches[0].to!long)];
    case "Calc.Floating":
      return cast(StackValue[])[bipush] ~ cast(StackValue[])[floating(p.matches[0].to!double)];
    case "Calc.ParameterList":
      StackValue[] args;

      foreach (c; p.children) {
        args ~= buildCode(c);
      }

      return args;
    case "Calc.Identifier":
      string ident = p.matches[0];
      bool found;
      foreach (key; Identifiers.keys) {
        if (key == ident) {
          found = true;
          break;
        }
      }
      if (!found) {
        throw new Error("Undefined identifier given : " ~ ident);
      }
      return cast(StackValue[])[funcs[ident]];
    case "Calc.Func":
      auto func = buildCode(p.children[0]);
      auto args  = buildCode(p.children[1]);
      return args ~ func;
    case "Calc.PowerExpr":
      auto n = buildCode(p.children[0]);
      auto m = buildCode(p.children[1]);
      return n ~ m ~ cast(StackValue[])[ipower];
  }
}
