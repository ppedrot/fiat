Require Import Coq.Strings.String Coq.Strings.Ascii Coq.Lists.List.
Require Import Fiat.Parsers.ContextFreeGrammar.Core.
Require Import Fiat.Common.List.Operations.
Require Import Fiat.Common.Equality.

Export Coq.Strings.Ascii.
Export Coq.Strings.String.
Export Fiat.Parsers.ContextFreeGrammar.Core.

Fixpoint production_of_string (s : string) : production Ascii.ascii
  := match s with
       | EmptyString => nil
       | String.String ch s' => (Terminal ch)::production_of_string s'
     end.

Coercion production_of_string : string >-> production.

Definition list_to_productions {T} (default : T) (ls : list (string * T)) : string -> T
  := fun nt
     => option_rect
          (fun _ => T)
          (fun idx => nth idx (map snd (uniquize (fun x y => string_beq (fst x) (fst y)) ls)) default)
          default
          (first_index_error (string_beq nt) (uniquize string_beq (map fst ls))).

Definition list_to_grammar {T} (default : productions T) (ls : list (string * productions T)) : grammar T
  := {| Start_symbol := hd ""%string (uniquize string_beq (map fst ls));
        Lookup := list_to_productions default ls;
        Valid_nonterminals := uniquize string_beq (map fst ls) |}.

Definition item_ascii := item Ascii.ascii.
Coercion item_of_char (ch : Ascii.ascii) : item_ascii := Terminal ch.
Coercion item_of_string (nt : string) : item_ascii := NonTerminal nt.
Definition item_ascii_cons : item_ascii -> production Ascii.ascii -> production Ascii.ascii := cons.
Global Arguments item_ascii_cons / .
Global Arguments item_of_char / .
Global Arguments item_of_string / .

Delimit Scope item_scope with item.
Bind Scope item_scope with item.
Delimit Scope production_scope with production.
Delimit Scope production_assignment_scope with prod_assignment.
Bind Scope production_scope with production.
Delimit Scope productions_scope with productions.
Delimit Scope productions_assignment_scope with prods_assignment.
Bind Scope productions_scope with productions.
Delimit Scope grammar_scope with grammar.
Bind Scope grammar_scope with grammar.
Notation "n0 ::== r0" := ((n0 : string)%string, (r0 : productions _)%productions) (at level 100) : production_assignment_scope.
Notation "[[[ x ;; .. ;; y ]]]" :=
  (list_to_productions nil (cons x%prod_assignment .. (cons y%prod_assignment nil) .. )) : productions_assignment_scope.
Notation "[[[ x ;; .. ;; y ]]]" :=
  (list_to_grammar nil (cons x%prod_assignment .. (cons y%prod_assignment nil) .. )) : grammar_scope.

Local Open Scope string_scope.
Notation "<< x | .. | y >>" :=
  (@cons (production _) (x)%production .. (@cons (production _) (y)%production nil) .. ) : productions_scope.

Notation "$< x $ .. $ y >$" := (item_ascii_cons x .. (item_ascii_cons y nil) .. ) : production_scope.
Notation "# c" := (c%char) (at level 0, only parsing) : production_scope.

Global Open Scope grammar_scope.
Global Open Scope string_scope.
