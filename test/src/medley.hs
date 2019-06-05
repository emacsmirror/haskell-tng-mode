{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE ScopedTypeVariables #-}

-- | This file is a medley of various constructs and some corner cases
module Foo.Bar.Main
  ( Wibble(..), Wobble(Wobb, (!!!)), Woo
  -- * Operations
  , getFooByBar, getWibbleByWobble
  , module Bloo.Foo
) where

import           Control.Applicative (many, optional, pure, (<*>), (<|>))
import           Data.Foldable       (traverse_)
import           Data.Functor        ((<$>))
import           Data.List           (intercalate)
import           Data.Monoid         ((<>))
import qualified Options.Monad
import  qualified  Options.Applicative  as  Opts
import qualified Options.Divisible -- wibble (wobble)
   as Div
import qualified ProfFile.App        hiding (as, hiding, qualified)
import           ProfFile.App        (as, hiding, qualified)
import           ProfFile.App        hiding (as, hiding, qualified)
import qualified ProfFile.App        (as, hiding, qualified)
import           System.Exit         (ExitCode (..), exitFailure, qualified,
                                      Typey,
                                      wibble,
                                      Wibble)
import           System.FilePath     (replaceExtension, Foo(Bar, (:<)))
import           System.IO           (IOMode (..), hClose, hGetContents,
                                      hPutStr, hPutStrLn, openFile, stderr,
                                      stdout, MoarTypey)
import           System.Process      (CreateProcess (..), StdStream (..),
                                      createProcess, proc, waitForProcess)

-- some chars that should be propertized
chars = ['c', '\n', '\'']

strings = ["", "\"\"", "\n\\ ", "\\"]
-- knownWrongEscape = "foo"\\"bar"

multiline1 = "\
        \ "
multiline2 = "\
         \"

difficult = foo' 'a' 2

foo = "wobble (wibble)"

class Get a s where
  get :: Set s -> a

instance {-# OVERLAPS #-} Get a (a ': s) where
  get (Ext a _) = a

instance {-# OVERLAPPABLE #-} Get a s => Get a (b ': s) where
  get (Ext _ xs) = get xs

data Options = Options
  { optionsReportType      :: ReportType
  , optionsProfFile        :: Maybe FilePath
  , optionsOutputFile      :: Maybe FilePath
  , optionsFlamegraphFlags :: [String]
  } deriving (Eq, Show)

class  (Eq a) => Ord a  where
  (<), (<=), (>=), (>)  :: a -> a -> Bool
  max @Foo, min        :: a -> a -> a

instance (Eq a) => Eq (Tree a) where
  Leaf a         == Leaf b          =  a == b
  (Branch l1 r1) == (Branch l2 r2)  =  (l1==l2) && (r1==r2)
  _              == _               =  False

data ReportType = Alloc   -- ^ Report allocations, percent
                | Entries -- ^ Report entries, number
                | Time    -- ^ Report time spent in closure, percent
                | Ticks   -- ^ Report ticks, number
                | Bytes   -- ^ Report bytes allocated, number
                deriving (Eq, Show)

type family G a where
  G Int = Bool
  G a   = Char

data Flobble = Flobble
  deriving (Eq) via (NonNegative (Large Int))
  deriving stock (Floo)
  deriving anyclass (WibblyWoo, OtherlyWoo)

newtype Flobby = Flobby

foo ::
 Wibble -- wibble
    -> Wobble -- wobble
    -> Wobble -- wobble
    -> Wobble -- wobble
    -> (wob :: Wobble)
    -> (Wobble -- wobble
    a b c)

(foo :: (Wibble Wobble)) foo

newtype TestApp
   (logger :: TestLogger)
   (scribe :: TestScribe)
   config
   a
   = TestApp a

optionsParser :: Opts.Parser Options
optionsParser = Options
  <$> (Opts.flag' Alloc (Opts.long "alloc" <> Opts.help "wibble")
       <|> Opts.flag' Entries (Opts.long "entry" <> Opts.help "wobble")
       <|> Opts.flag' Bytes   (Opts.long "bytes" <> Opts.help "i'm a fish"))
  <*> optional
        (Opts.strArgument
          (Opts.metavar "MY-FILE" <>
           Opts.help "meh"))

type PhantomThing

type SomeApi =
       "thing" :> Capture "bar" Index :> QueryParam "wibble" Text
                                               :> QueryParam "wobble" Natural
                                               :> Header TracingHeader TracingId
                                               :> ThingHeader
                                               :> Get '[JSON] (The ReadResult)
  :<|> "thing" :> ReqBody '[JSON] Request
                      :> Header TracingHeader TracingId
                      :> SpecialHeader
                      :> Post '[JSON] (The Response)

deriving instance FromJSONKey StateName
deriving anyclass instance FromJSON Base
deriving newtype instance FromJSON Treble

foo = do
  bar :: Wibble <- baz
  where baz = _
  -- checking that comments are ignored in layout
  -- and that a starting syntax entry is ok
        (+) = _

test = 1 `shouldBe` 1

bar = do -- an incomplete do block
