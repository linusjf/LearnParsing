%option noyywrap
/* recognize tokens for the calculator and print them out */
%{
#include <iostream>
#include <string>
#include "calccpp.tab.hh"
using token = yy::parser::token;
FlexLexer* lexer = new yyFlexLexer;

int yylex(yy::parser::semantic_type* yylval) {
  return lexer->yylex();
}
extern yy::parser::semantic_type yylval;
%}
%%
"+" { return token::ADD; }
"-" { return token::SUB; }
"*" { return token::MUL; }
"/" { return token::DIV; }
"|" { return token::ABS; }
"%" { return token::MOD; }
[0-9]+ { yylval.value = std::stod(lexer->YYText()); return token::NUMBER; }
[0-9]+.[0-9]+ { yylval.value = std::stod(lexer->YYText()); return token::NUMBER; }
\n { return token::EOL; }
[ \t] { /* ignore whitespace */ }
"(" { return token::OP; }
")" { return token::CP; }
"//".* /* ignore comments */
. {
  using namespace std;
  cout << "Mystery character " << *yytext << endl; 
}
%%
