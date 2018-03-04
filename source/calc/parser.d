module calc.parser;
import pegged.grammar;
import calc.vm;
import std.stdio,
       std.conv;

mixin(grammar(`
Calc:
  Term < VariableAssign / Factor (Add / Sub)*
  Add < "+" Factor
  Sub < "-" Factor
  Factor < Primary (Mul / Div / Mod)*
  Mul < "*" Factor
  Div < "/" Factor
  Mod < "%" Factor

  Primary < Parens / Func / PowerExpr / Variable / Number

  Parens < :"(" Term :")"

  Func < Identifier ParameterList
  ParameterList < "()" / :"(" Parameter ("," Parameter)* :")"
  Parameter < Primary
  Variable < Identifier
  VariableAssign < Variable "=" Term

  PowerExpr < Number "^" Integer

  Identifier <~ [a-zA-Z_] [a-zA-Z0-9_]*
  Number < Floating / Integer
  Integer <~ Sign? digit+
  Floating <~ Sign? [0-9]+ "." [0-9]+
  Sign <- "-" / "+"
`));

StackValue[string] idents;
enum Identifiers = [
  "sqrt" : function Func ()  { return sqrt; },
  "square" : function Func () { return square; } 
];

static this() {
  foreach (key; Identifiers.keys) {
    idents[key] = Identifiers[key]();
  }
}

void setVariable(string name, StackValue value) {
  idents[name] = value;
}

StackValue getVariable(string name) {
  if (name !in idents) {
    throw new Error("no such a variable/func - " ~ name);
  }
  return idents[name];
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
      foreach (key; idents.keys) {
        if (key == ident) {
          found = true;
          break;
        }
      }
      if (!found) {
        throw new Error("Undefined identifier given : " ~ ident);
      }
      return cast(StackValue[])[idents[ident]];
    case "Calc.Func":
      auto func = buildCode(p.children[0]);
      auto args  = buildCode(p.children[1]);
      return args ~ func;
    case "Calc.PowerExpr":
      auto n = buildCode(p.children[0]);
      auto m = buildCode(p.children[1]);
      return n ~ m ~ cast(StackValue[])[ipower];
    case "Calc.Variable":
      return [variable(p.matches[0])];
    case "Calc.VariableAssign":
      string name = p.matches[0];
      StackValue[] value = buildCode(p.children[1]);
      Integer len = integer(value.length.to!long);
      return vassign ~ cast(StackValue[])[variable(name)] ~ len ~ value;
  }
}
