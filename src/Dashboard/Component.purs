module Dashboard.Component where

import Prelude

import Control.Monad.Aff (Aff)
import Control.Monad.Aff.Class (liftAff)
import Control.Monad.Aff.Console (CONSOLE, log)
import Dashboard.Model (PipelineRow, createdDateTime, makeProjectRows)
import Dashboard.View (formatPipeline)
import Data.Array as Array
import Data.Maybe (Maybe(..))
import Gitlab as Gitlab
import Global.Unsafe (unsafeStringify)
import Halogen as H
import Halogen.Aff (HalogenEffects)
import Halogen.HTML as HH
import Halogen.HTML.Properties as HP
import Network.HTTP.Affjax (AJAX)

type State = Array PipelineRow

data Query a
  = UpsertProjectPipelines (Array PipelineRow) a
  | FetchJobs Gitlab.Project a

type Effects = HalogenEffects
  ( console :: CONSOLE
  , ajax    :: AJAX
  )

type Config =
  { baseUrl :: Gitlab.BaseUrl
  , token   :: Gitlab.Token
  }

ui :: Config -> H.Component HH.HTML Query Unit Void (Aff Effects)
ui { baseUrl, token } =
  H.component
    { initialState: const initialState
    , render
    , eval
    , receiver: const Nothing
    }
  where

  initialState :: State
  initialState = []

  render :: State -> H.ComponentHTML Query
  render pipelines =
    HH.table
      [ HP.classes [ H.ClassName "table"
                  , H.ClassName "table-dark"
                  ]
      ]
      [ HH.thead_
          [ HH.tr_ [ HH.th_ [ HH.text "Status" ]
                   , HH.th_ [ HH.text "Repo" ]
                   , HH.th_ [ HH.text "Commit" ]
                   , HH.th_ [ HH.text "Stages" ]
                   , HH.th_ [ HH.text "Time" ]
                   ]
          ]
      , HH.tbody_ $ map formatPipeline pipelines
      ]

  eval :: Query ~> H.ComponentDSL State Query Void (Aff Effects)
  eval = case _ of
    FetchJobs project@{ id: Gitlab.ProjectId pid } next -> next <$ do
      liftAff $ log $ "Fetching Jobs for Project with id: " <> show pid
      jobs <- liftAff $ Gitlab.getJobs baseUrl token project
      eval $ UpsertProjectPipelines (makeProjectRows jobs) next

    UpsertProjectPipelines pipelines next -> next <$ do
      H.modify
        $ Array.take 40
        <<< Array.reverse
        <<< Array.sortWith createdDateTime
        -- Always include the pipelines passed as new data.
        -- Filter out of the state the pipelines that we have in the new data,
        -- and merge the remaining ones to get the new state.
        <<< (pipelines <> _)
        <<< Array.filter (\pr -> not $ Array.elem pr.id (map _.id pipelines))
