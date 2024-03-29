/* Parser for mfcalc.   -*- C -*-

   Copyright (C) 1988-1993, 1995, 1998-2015, 2018-2021 Free Software
   Foundation, Inc.

   This file is part of Bison, the GNU Compiler Compiler.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <https://www.gnu.org/licenses/>.  */

%{
  #include <stdio.h>  /* For printf, etc. */
  #include <math.h>   /* For pow, used in the grammar. */
  #include "mfcalc.h"   /* Contains definition of 'symrec'. */
  int yylex (void);
  void yyerror (char const *);
%}

%define api.value.type union /* Generate YYSTYPE from these types: */
%token <double>  NUM     /* Double precision number. */
%token <symrec*> VAR FUN CONST /* Symbol table pointer: variable/function. */
%nterm <double>  exp

/*%precedence '='*/
%left '-' '+'
%left '*' '/' '%' '|'
%precedence NEG /* negation--unary minus */
%right '^'      /* exponentiation */
%right '='      /* equality */
/* Generate the parser description file. */
%verbose
/* Enable run-time traces (yydebug). */
%define parse.trace
%define parse.lac full

/* Formatting semantic values. */
%printer { fprintf (yyo, "%s", $$->name); } VAR;
%printer { fprintf (yyo, "%s()", $$->name); } FUN;
%printer { fprintf (yyo, "%g", $$); } <double>;
%% /* The grammar follows. */
input: %empty;
input: input line;

line: '\n';
line: exp '\n'   { printf ("%.10g\n", $1); };
line: error '\n' { yyerrok;};

exp: NUM
exp: VAR                { $$ = $1->value.var;};
exp: CONST              { $$ = $1->value.var;};
exp: VAR '=' exp        { $$ = $3; $1->value.var = $3;};
exp: FUN '(' exp ')'    { $$ = $1->value.fun ($3);};
exp: exp '+' exp        { $$ = $1 + $3;};
exp: exp '-' exp        { $$ = $1 - $3;};
exp: exp '*' exp        { $$ = $1 * $3;};
exp: exp '/' exp        { $$ = $1 / $3;};
exp: exp '%' exp        { $$ = fmod($1,$3);};
exp: '-' exp  %prec NEG { $$ = -$2;};
exp: '+' exp            { $$ = $2;};
exp: exp '^' exp        { $$ = pow ($1, $3);};
exp: '|' exp '|'        { $$ = fabs($2);};
exp: '(' exp ')'        { $$ = $2;};

/* End of grammar. */
%%

struct init
{
  char const *name;
  func_t *fun;
};

struct initvar
{
  char const *name;
  double var;
};

struct init const funs[] =
{
  { "atan", atan },
  { "cos",  cos  },
  { "cosh",  cosh  },
  { "acos",  acos  },
  { "exp",  exp  },
  { "ln",   log  },
  { "log10",   log10  },
  { "sin",  sin  },
  { "sinh",  sinh  },
  { "asin",  asin  },
  { "sqrt", sqrt },
  { "tan", tan },
  { "tanh", tanh },
  { "ceil", ceil },
  { "floor", floor },
  { 0, 0 },
};

struct initvar const vars[] =
{
  { "PI", M_PI },
  { "E",  M_E  },
  { 0, 0 },
};

/* The symbol table: a chain of 'struct symrec'. */
symrec *sym_table;

/* Put functions in table. */
static void
init_table (void)
{
  for (int i = 0; funs[i].name; i++)
    {
      symrec *ptr = putsym (funs[i].name, FUN);
      ptr->value.fun = funs[i].fun;
    }
  for (int i = 0; vars[i].name; i++)
    {
      symrec *ptr = putsym (vars[i].name, VAR);
      ptr->value.var = vars[i].var;
    }
}

/* The mfcalc code assumes that malloc and realloc
   always succeed, and that integer calculations
   never overflow.  Production-quality code should
   not make these assumptions.  */
#include <assert.h>
#include <stdlib.h> /* malloc, realloc. */
#include <string.h> /* strlen. */

symrec *
putsym (char const *name, int sym_type)
{
  symrec *res = (symrec *) malloc (sizeof (symrec));
  res->name = strdup (name);
  res->type = sym_type;
  res->value.var = 0; /* Set value to 0 even if fun. */
  res->next = sym_table;
  sym_table = res;
  return res;
}

symrec *
getsym (char const *name)
{
  for (symrec *p = sym_table; p; p = p->next)
    if (strcmp (p->name, name) == 0)
      return p;
  return NULL;
}

#include <ctype.h>
#include <stddef.h>

int
yylex (void)
{
  int c = getchar ();

  /* Ignore white space, get first nonwhite character. */
  while (c == ' ' || c == '\t')
    c = getchar ();

  if (c == EOF)
    return YYEOF;

  /* Char starts a number => parse the number. */
  if (c == '.' || isdigit (c))
    {
      ungetc (c, stdin);
      if (scanf ("%lf", &yylval.NUM) != 1)
        abort ();
      return NUM;
    }

  /* Char starts an identifier => read the name. */
  if (isalpha (c))
    {
      static ptrdiff_t bufsize = 0;
      static char *symbuf = 0;
      ptrdiff_t i = 0;
      do
        {
          /* If buffer is full, make it bigger. */
          if (bufsize <= i)
            {
              bufsize = 2 * bufsize + 40;
              symbuf = realloc (symbuf, (size_t) bufsize);
            }
          /* Add this character to the buffer. */
          symbuf[i++] = (char) c;
          /* Get another character. */
          c = getchar ();
        }
      while (isalnum (c));

      ungetc (c, stdin);
      symbuf[i] = '\0';

      symrec *s = getsym (symbuf);
      if (!s)
        s = putsym (symbuf, VAR);
      yylval.VAR = s; /* or yylval.FUN = s. */
      return s->type;
    }

  /* Any other character is a token by itself. */
  return c;
}

/* Called by yyparse on error. */
void yyerror (char const *s)
{
  fprintf (stderr, "%s\n", s);
}

int main (int argc, char const* argv[])
{
  /* Enable parse traces on option -p. */
  if (argc == 2 && strcmp(argv[1], "-p") == 0)
    yydebug = 1;
  init_table ();
  return yyparse ();
}

