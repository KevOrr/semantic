module TermSpec where

import Test.Hspec
import Test.Hspec.QuickCheck
import Test.QuickCheck hiding (Fixed)
import Data.Text.Arbitrary ()

import Categorizable
import Control.Comonad.Cofree
import Control.Monad
import GHC.Generics
import qualified Data.List as List
import qualified Data.Set as Set
import qualified OrderedMap as Map
import Diff
import Interpreter
import Syntax
import Term

newtype ArbitraryTerm a annotation = ArbitraryTerm (annotation, (Syntax a (ArbitraryTerm a annotation)))
  deriving (Show, Eq, Generic)

unTerm :: ArbitraryTerm a annotation -> Term a annotation
unTerm = unfold unpack
  where unpack (ArbitraryTerm (annotation, syntax)) = (annotation, syntax)

instance (Eq a, Eq annotation, Arbitrary a, Arbitrary annotation) => Arbitrary (ArbitraryTerm a annotation) where
  arbitrary = sized (\ x -> boundedTerm x x) -- first indicates the cube of the max length of lists, second indicates the cube of the max depth of the tree
    where boundedTerm maxLength maxDepth = ArbitraryTerm <$> ((,) <$> arbitrary <*> boundedSyntax maxLength maxDepth)
          boundedSyntax _ maxDepth | maxDepth <= 0 = liftM Leaf arbitrary
          boundedSyntax maxLength maxDepth = frequency
            [ (12, liftM Leaf arbitrary),
              (1, liftM Indexed $ take maxLength <$> listOf (smallerTerm maxLength maxDepth)),
              (1, liftM Fixed $ take maxLength <$> listOf (smallerTerm maxLength maxDepth)),
              (1, liftM (Keyed . Map.fromList) $ take maxLength <$> listOf (arbitrary >>= (\x -> ((,) x) <$> smallerTerm maxLength maxDepth))) ]
          smallerTerm maxLength maxDepth = boundedTerm (div maxLength 3) (div maxDepth 3)
  shrink term@(ArbitraryTerm (annotation, syntax)) = (++) (subterms term) $ filter (/= term) $
    ArbitraryTerm <$> ((,) <$> shrink annotation <*> case syntax of
      Leaf a -> Leaf <$> shrink a
      Indexed i -> Indexed <$> (List.subsequences i >>= recursivelyShrink)
      Fixed f -> Fixed <$> (List.subsequences f >>= recursivelyShrink)
      Keyed k -> Keyed . Map.fromList <$> (List.subsequences (Map.toList k) >>= recursivelyShrink))

data CategorySet = A | B | C | D deriving (Eq, Show)

instance Categorizable CategorySet where
  categories A = Set.fromList [ "a" ]
  categories B = Set.fromList [ "b" ]
  categories C = Set.fromList [ "c" ]
  categories D = Set.fromList [ "d" ]

instance Arbitrary CategorySet where
  arbitrary = elements [ A, B, C, D ]

main :: IO ()
main = hspec spec

spec :: Spec
spec = do
  describe "Term" $ do
    prop "equality is reflexive" $
      \ a -> unTerm a == unTerm (a :: ArbitraryTerm String ())

  describe "Diff" $ do
    prop "equality is reflexive" $
      \ a b -> let diff = interpret comparable (unTerm a) (unTerm (b :: ArbitraryTerm String CategorySet)) in
        diff == diff

    prop "equal terms produce identity diffs" $
      \ a -> let term = unTerm (a :: ArbitraryTerm String CategorySet) in
        diffCost (interpret comparable term term) == 0
