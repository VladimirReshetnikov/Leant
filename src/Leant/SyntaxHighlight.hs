-- | A small, total lexical highlighter for Lean source shown by the REPL.
--
-- This module is deliberately presentation-only. It does not decide whether
-- input is valid Lean and none of its classifications may be used for command
-- dispatch, replay, or backend requests. Keeping the scanner pure also makes
-- the disabled path an exact textual identity for redirected output.
module Leant.SyntaxHighlight
  ( highlightLean
  , stripSgr
  ) where

import Data.Char
  ( GeneralCategory (..)
  , generalCategory
  , isAlpha
  , isAlphaNum
  , isDigit
  , isHexDigit
  , isSpace
  , isUpper
  )
import Data.List (isPrefixOf)
import qualified Data.Set as Set

-- | Lexical presentation classes. They intentionally carry no parsing or
-- elaboration authority: capitalization and leading-dot constructor notation
-- are only display heuristics.
data SyntaxStyle
  = PlainStyle
  | KeywordStyle
  | ConstructorStyle
  | LiteralStyle
  | NumberStyle
  | CommentStyle
  | OperatorStyle

data SyntaxSpan = SyntaxSpan SyntaxStyle String

-- | Colorize Lean-like source with portable SGR sequences. Disabling the
-- renderer returns the original value without even scanning it; this is the
-- byte-preserving path used for redirected and scripted output.
highlightLean :: Bool -> String -> String
highlightLean False source = source
highlightLean True source = renderSpans (scan source)

-- | Remove numeric Select Graphic Rendition control sequences while leaving
-- other CSI controls untouched. The highlighter emits only this SGR subset,
-- so @stripSgr (highlightLean True source) == source@ for ordinary source text.
stripSgr :: String -> String
stripSgr [] = []
stripSgr ('\ESC' : '[' : rest) =
  case span isSgrParameter rest of
    (_, 'm' : remaining) -> stripSgr remaining
    _ -> '\ESC' : '[' : stripSgr rest
 where
  isSgrParameter character =
    isDigit character || character == ';' || character == ':'
stripSgr (character : rest) = character : stripSgr rest

scan :: String -> [SyntaxSpan]
scan [] = []
scan source@('-' : '-' : _) =
  let (comment, remaining) = break (== '\n') source
  in SyntaxSpan CommentStyle comment : scan remaining
scan source@('/' : '-' : _) =
  let (comment, remaining) = takeBlockComment source
  in SyntaxSpan CommentStyle comment : scan remaining
scan source@('"' : _) =
  let (literal, remaining) = takeStringLiteral source
  in SyntaxSpan LiteralStyle literal : scan remaining
scan source@('\'' : rest) = case takeCharacterLiteral source of
  Just (literal, remaining) ->
    SyntaxSpan LiteralStyle literal : scan remaining
  Nothing -> SyntaxSpan OperatorStyle "'" : scan rest
scan source@('\171' : _) =
  let (identifier, remaining) = takeQuotedIdentifier source
  in SyntaxSpan ConstructorStyle identifier : scan remaining
scan ('#' : character : rest)
  | isIdentifierStart character =
      let (suffix, remaining) = span isIdentifierContinue (character : rest)
      in SyntaxSpan KeywordStyle ('#' : suffix) : scan remaining
scan ('.' : character : rest)
  | isIdentifierStart character =
      let (name, remaining) = span isIdentifierContinue (character : rest)
      in SyntaxSpan OperatorStyle "."
          : SyntaxSpan ConstructorStyle name
          : scan remaining
scan source@(character : rest)
  | isDigit character =
      let (number, remaining) = takeNumber source
      in SyntaxSpan NumberStyle number : scan remaining
  | isIdentifierStart character =
      let (identifier, remaining) = span isIdentifierContinue source
      in SyntaxSpan (identifierStyle identifier) identifier : scan remaining
  | isOperatorCharacter character =
      let (operator, remaining) = takeOperator source
      in SyntaxSpan OperatorStyle operator : scan remaining
  | isSpace character =
      let (whitespace, remaining) = span isSpace source
      in SyntaxSpan PlainStyle whitespace : scan remaining
  | otherwise = SyntaxSpan PlainStyle [character] : scan rest

identifierStyle :: String -> SyntaxStyle
identifierStyle identifier
  | Set.member identifier leanKeywords = KeywordStyle
  | Set.member identifier primitiveTypes = ConstructorStyle
  | firstIsUpper identifier = ConstructorStyle
  | otherwise = PlainStyle
 where
  firstIsUpper (first : _) = isUpper first
  firstIsUpper [] = False

isIdentifierStart :: Char -> Bool
isIdentifierStart character =
  isAlpha character || character == '_' || character == '?'

isIdentifierContinue :: Char -> Bool
isIdentifierContinue character =
  isAlphaNum character || elem character "_'?!"

-- Lean admits a broad Unicode operator vocabulary. General-category
-- classification keeps mathematical arrows and user notation together while
-- leaving letters (including Greek identifiers) to the identifier scanner.
isOperatorCharacter :: Char -> Bool
isOperatorCharacter character = case generalCategory character of
  ConnectorPunctuation -> True
  DashPunctuation -> True
  OpenPunctuation -> True
  ClosePunctuation -> True
  InitialQuote -> True
  FinalQuote -> True
  OtherPunctuation -> True
  MathSymbol -> True
  CurrencySymbol -> True
  ModifierSymbol -> True
  OtherSymbol -> True
  _ -> False

-- Stop a punctuation run before another lexical token. Strings, character
-- literals, quoted identifiers, commands, comments, and leading-dot
-- constructors may all be adjacent to an opening or separating operator.
takeOperator :: String -> (String, String)
takeOperator [] = ("", [])
takeOperator (first : rest) = go [first] rest
 where
  go reverseOperator remaining@('-' : '-' : _) =
    (reverse reverseOperator, remaining)
  go reverseOperator remaining@('/' : '-' : _) =
    (reverse reverseOperator, remaining)
  go reverseOperator remaining@('"' : _) =
    (reverse reverseOperator, remaining)
  go reverseOperator remaining@('\'' : _) =
    (reverse reverseOperator, remaining)
  go reverseOperator remaining@('\171' : _) =
    (reverse reverseOperator, remaining)
  go reverseOperator remaining@('#' : next : _)
    | isIdentifierStart next = (reverse reverseOperator, remaining)
  go reverseOperator remaining@('.' : next : _)
    | isIdentifierStart next = (reverse reverseOperator, remaining)
  go reverseOperator (character : remaining)
    | isOperatorCharacter character =
        go (character : reverseOperator) remaining
  go reverseOperator remaining = (reverse reverseOperator, remaining)

takeStringLiteral :: String -> (String, String)
takeStringLiteral ('"' : rest) = go ['"'] rest
 where
  go reverseLiteral [] = (reverse reverseLiteral, [])
  go reverseLiteral ('\\' : escaped : remaining) =
    go (escaped : '\\' : reverseLiteral) remaining
  go reverseLiteral ['\\'] = (reverse ('\\' : reverseLiteral), [])
  go reverseLiteral ('"' : remaining) =
    (reverse ('"' : reverseLiteral), remaining)
  go reverseLiteral (character : remaining) =
    go (character : reverseLiteral) remaining
takeStringLiteral source = ("", source)

-- Character literals cannot cross a physical line. If no unescaped closing
-- quote is present, leave the leading quote as punctuation and let the outer
-- scanner classify the remaining text normally.
takeCharacterLiteral :: String -> Maybe (String, String)
takeCharacterLiteral ('\'' : rest) = go ['\''] rest
 where
  go _ [] = Nothing
  go _ ('\n' : _) = Nothing
  go reverseLiteral ('\\' : escaped : remaining) =
    go (escaped : '\\' : reverseLiteral) remaining
  go _ ['\\'] = Nothing
  go reverseLiteral ('\'' : remaining) =
    Just (reverse ('\'' : reverseLiteral), remaining)
  go reverseLiteral (character : remaining) =
    go (character : reverseLiteral) remaining
takeCharacterLiteral _ = Nothing

takeQuotedIdentifier :: String -> (String, String)
takeQuotedIdentifier ('\171' : rest) = go ['\171'] rest
 where
  go reverseIdentifier [] = (reverse reverseIdentifier, [])
  go reverseIdentifier ('\187' : remaining) =
    (reverse ('\187' : reverseIdentifier), remaining)
  go reverseIdentifier (character : remaining) =
    go (character : reverseIdentifier) remaining
takeQuotedIdentifier source = ("", source)

-- Lean block comments nest. Consume one complete comment or the entire
-- remaining input when it is unterminated, retaining every byte either way.
takeBlockComment :: String -> (String, String)
takeBlockComment ('/' : '-' : rest) = go 1 ['-', '/'] rest
 where
  go :: Int -> String -> String -> (String, String)
  go _ reverseComment [] = (reverse reverseComment, [])
  go depth reverseComment ('/' : '-' : remaining) =
    go (depth + 1) ('-' : '/' : reverseComment) remaining
  go depth reverseComment ('-' : '/' : remaining)
    | depth == 1 =
        (reverse ('/' : '-' : reverseComment), remaining)
    | otherwise =
        go (depth - 1) ('/' : '-' : reverseComment) remaining
  go depth reverseComment (character : remaining) =
    go depth (character : reverseComment) remaining
takeBlockComment source = ("", source)

takeNumber :: String -> (String, String)
takeNumber source
  | isPrefixOf "0x" source || isPrefixOf "0X" source =
      takeBasedNumber isHexDigit source
  | isPrefixOf "0b" source || isPrefixOf "0B" source =
      takeBasedNumber (\character -> elem character "01") source
  | isPrefixOf "0o" source || isPrefixOf "0O" source =
      takeBasedNumber (\character -> elem character "01234567") source
  | otherwise = takeDecimalNumber source

takeBasedNumber :: (Char -> Bool) -> String -> (String, String)
takeBasedNumber isBaseDigit (zero : prefix : rest) =
  let (digits, remaining) = span isDigitOrSeparator rest
  in (zero : prefix : digits, remaining)
 where
  isDigitOrSeparator character =
    isBaseDigit character || character == '_'
takeBasedNumber _ source = ("", source)

takeDecimalNumber :: String -> (String, String)
takeDecimalNumber source =
  let (whole, afterWhole) = span isDecimalDigit source
      (fraction, afterFraction) = case afterWhole of
        '.' : next : rest
          | isDigit next ->
              let (digits, afterDigits) = span isDecimalDigit (next : rest)
              in ('.' : digits, afterDigits)
        _ -> ("", afterWhole)
      (exponentPart, afterNumber) = takeExponent afterFraction
  in (whole ++ fraction ++ exponentPart, afterNumber)
 where
  isDecimalDigit character = isDigit character || character == '_'

  takeExponent (marker : rest)
    | marker == 'e' || marker == 'E' =
        let (sign, afterSign) = case rest of
              signCharacter : after
                | signCharacter == '+' || signCharacter == '-' ->
                    ([signCharacter], after)
              _ -> ("", rest)
            (digits, afterDigits) = span isDecimalDigit afterSign
        in if any isDigit digits
             then (marker : sign ++ digits, afterDigits)
             else ("", marker : rest)
  takeExponent rest = ("", rest)

renderSpans :: [SyntaxSpan] -> String
renderSpans spans = foldr renderNext id spans ""
 where
  renderNext syntaxSpan remaining = renderSpan syntaxSpan . remaining

renderSpan :: SyntaxSpan -> ShowS
renderSpan (SyntaxSpan PlainStyle text) = showString text
renderSpan (SyntaxSpan style text) =
  showString "\ESC["
    . showString (styleCode style)
    . showString "m"
    . showString text
    . showString "\ESC[0m"

styleCode :: SyntaxStyle -> String
styleCode PlainStyle = "0"
styleCode KeywordStyle = "1;34"
styleCode ConstructorStyle = "36"
styleCode LiteralStyle = "32"
styleCode NumberStyle = "35"
styleCode CommentStyle = "2"
styleCode OperatorStyle = "33"

primitiveTypes :: Set.Set String
primitiveTypes = Set.fromList
  [ "Bool", "Empty", "Except", "False", "Int", "List", "Nat"
  , "Option", "Prod", "Prop", "Sort", "String", "Sum", "True"
  , "Type", "Unit"
  ]

-- A presentation vocabulary, not a grammar. Unknown syntax remains visible
-- and unstyled; adding a keyword here can never change what the REPL executes.
leanKeywords :: Set.Set String
leanKeywords = Set.fromList
  [ "abbrev", "add_decl_doc", "aesop?", "alias", "apply", "as"
  , "assumption", "at", "attribute", "axiom", "binder_predicate", "builtin_initialize"
  , "by", "calc", "case", "cases", "catch", "class", "constructor"
  , "contradiction", "declare_syntax_cat", "decide", "decreasing_by", "def"
  , "deriving", "do", "elab", "elab_rules", "else", "end", "example"
  , "exact", "exact?", "export", "extends", "false", "finally", "first"
  , "for", "from", "fun", "gen_injective_theorems", "have", "if", "import"
  , "in", "include", "induction", "inductive", "infix", "infixl", "infixr"
  , "initialize", "instance", "intro", "intros", "left", "lemma", "let"
  , "local", "macro", "macro_rules", "match", "mutual", "namespace", "next"
  , "nomatch", "noncomputable", "notation", "obtain", "of", "omega", "omit"
  , "opaque", "open", "partial", "postfix", "prefix", "private", "protected"
  , "recall", "return", "rfl", "right", "run_cmd", "run_elab", "rw", "rw?"
  , "scoped", "section", "set_option", "show", "show_panel_widgets", "simp"
  , "simp?", "simp_all", "structure", "syntax", "termination_by", "theorem"
  , "then", "true", "trivial", "try", "unif_hint", "universe", "unless"
  , "unsafe", "variable", "variables", "where", "while", "with", "\955"
  ]
