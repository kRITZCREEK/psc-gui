module Psc.Gui.Component.Import (importF) where

import           Control.Monad.Eff
import           Control.Monad.Eff.Class
import           Control.Monad.Eff.Console
import           Data.Array (head)
import           Data.Either
import           Data.Maybe
import           Data.String (joinWith)
import           Electron.Dialog
import           Node.Process
import           Prelude
import           Psc.Gui.Component.Util
import           Psc.Ide.Command

import qualified Thermite as T

import qualified React as R
import qualified React.DOM as D
import qualified React.DOM.Props as P

data Action = Submit | Dialog
type State = {
  input   :: String,
  imports :: Array Import
  }
initialState = {input: "", imports: []}
type Props = Unit
type ImportEff eff = (process :: PROCESS, dialog :: DIALOG, console :: CONSOLE | eff)

prettyImport :: Import -> String
prettyImport (Import i) = prettyImport' i
  where prettyImport' ({ moduleName: moduleName,
                         importType: Implicit,
                         qualifier: Nothing }) = "import " ++ moduleName
        prettyImport' ({ moduleName: moduleName,
                         importType: Implicit,
                         qualifier: Just q }) = "import qualified " ++ moduleName ++ " as " ++ q
        prettyImport' ({ moduleName: moduleName,
                         importType: Explicit idents,
                         qualifier: Nothing }) =
          "import " ++ moduleName ++ " ( " ++ joinWith ", " idents ++ " )"
        prettyImport' ({ moduleName: moduleName,
                         importType: Hiding idents,
                         qualifier: Nothing }) =
          "import " ++ moduleName ++ " hiding ( " ++ joinWith ", " idents ++ " )"

render :: T.Render State Props Action
render send _ s children = [D.div [P.key "import"] ([
  D.p' [D.text s.input],
  sbutton "blue"
    [P.onClick \_ -> send Submit]
    [D.text "Refresh"],
  sbutton "red"
    [P.onClick \_ -> send Dialog]
    [D.text "Choose File"]
  ] ++ map (\i -> D.p' [D.text (prettyImport i)]) s.imports)]

performAction :: forall eff. T.PerformAction (ImportEff eff) State Props Action
performAction Submit _ s k = do
  dir <- listImports s.input
  case dir of
    Right (ImportList imports) -> k (s { imports=imports })
    Left err -> log err
performAction Dialog _ s k = do
  response <- cwd
  paths <- showOpenDialog (defaultOpts {defaultPath=unwrapDir response, title="Choose a file to parse"})
  k (s {input=fromMaybe "" (head (fromMaybe [""] paths))})
  where unwrapDir (Right (Message d)) = d
        unwrapDir _ = ""

spec :: forall eff. T.Spec (ImportEff eff) State Props Action
spec = T.simpleSpec performAction render

importF :: R.ReactElement
importF = R.createFactory (T.createClass spec initialState) unit
