{-# LANGUAGE DataKinds, DeriveGeneric, DeriveAnyClass #-}
module Language where

import Control.Comonad.Trans.Cofree hiding (cofree, (:<))
import Data.Aeson
import Data.Foldable
import Data.Record
import GHC.Generics
import Info
import qualified Syntax as S
import Term

-- | A programming language.
data Language
    = Go
    | JavaScript
    | JSON
    | JSX
    | Markdown
    | Python
    | Ruby
    | TypeScript
    deriving (Show, Eq, Read, Generic, ToJSON)

-- | Returns a Language based on the file extension (including the ".").
languageForType :: String -> Maybe Language
languageForType mediaType = case mediaType of
    ".json" -> Just JSON
    ".md" -> Just Markdown
    ".rb" -> Just Ruby
    ".go" -> Just Language.Go
    ".js" -> Just TypeScript
    ".ts" -> Just TypeScript
    ".tsx" -> Just TypeScript
    ".jsx" -> Just JSX
    ".py" -> Just Python
    _ -> Nothing

toVarDeclOrAssignment :: HasField fields Category => Term S.Syntax (Record fields) -> Term S.Syntax (Record fields)
toVarDeclOrAssignment child = case unwrap child of
  S.Indexed [child', assignment] -> setCategory (extract child) VarAssignment :< S.VarAssignment [child'] assignment
  S.Indexed [child'] -> setCategory (extract child) VarDecl :< S.VarDecl [child']
  S.VarDecl _ -> setCategory (extract child) VarDecl :< unwrap child
  S.VarAssignment _ _ -> child
  _ -> toVarDecl child

toVarDecl :: HasField fields Category => Term S.Syntax (Record fields) -> Term S.Syntax (Record fields)
toVarDecl child = setCategory (extract child) VarDecl :< S.VarDecl [child]

toTuple :: Term S.Syntax (Record fields) -> [Term S.Syntax (Record fields)]
toTuple child | S.Indexed [key,value] <- unwrap child = [extract child :< S.Pair key value]
toTuple child | S.Fixed [key,value] <- unwrap child = [extract child :< S.Pair key value]
toTuple child | S.Leaf c <- unwrap child = [extract child :< S.Comment c]
toTuple child = pure child

toPublicFieldDefinition :: HasField fields Category => [SyntaxTerm fields] -> Maybe (S.Syntax (SyntaxTerm fields))
toPublicFieldDefinition children = case break (\x -> category (extract x) == Identifier) children of
  (prev, [identifier, assignment]) -> Just $ S.VarAssignment (prev ++ [identifier]) assignment
  (_, [_]) -> Just $ S.VarDecl children
  _ -> Nothing

toInterface :: HasField fields Category => [SyntaxTerm fields] -> Maybe (S.Syntax (SyntaxTerm fields))
toInterface (id : rest) = case break (\x -> category (extract x) == Other "object_type") rest of
  (clauses, [body]) -> Just $ S.Interface id clauses (toList (unwrap body))
  _ -> Nothing
toInterface _ = Nothing
