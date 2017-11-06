module Dashboard.Model where

import Data.Array
import Data.DateTime
import Data.JSDate
import Data.NonEmpty
import Data.Time.Duration
import Data.URI
import Gitlab
import Prelude

import Halogen.HTML.Core (ClassName(..))

type PipelineRow =
  { authorImg   :: URI
  , commitTitle :: String
  , hash        :: CommitShortHash
  , branch      :: BranchName
  , created     :: DateTime
  , status      :: PipelineStatus
  , id          :: PipelineId
  , project     :: Project
  , stages      :: Jobs
  , duration    :: Milliseconds
  }

rowColors :: PipelineStatus -> ClassName
rowColors status = case status of
  Running  -> ClassName "bg-primary"
  Pending  -> ClassName "bg-info"
  Success  -> ClassName "bg-success"
  Failed   -> ClassName "bg-danger"
  Canceled -> ClassName "bg-warning"
  Skipped  -> ClassName "bg-none"

-- TODO: return an HTML element instead. See status2icon
statusIcons :: JobStatus -> String
statusIcons status = case status of
  JobCreated  -> "dot-circle-o"
  JobManual   -> "user-circle-o"
  JobRunning  -> "refresh"
  JobPending  -> "question-circle-o"
  JobSuccess  -> "check-circle-o"
  JobFailed   -> "times-circle-o"
  JobCanceled -> "stop-circle-o"
  JobSkipped  -> "arrow-circle-o-right"

getUniqueStages :: Jobs -> Array JobStatus
getUniqueStages jobs = map jobStatus
                       $ sortWith jobId
                       $ catMaybes
                       $ map (\grp -> last
                                      $ sortWith jobId
                                      $ fromNonEmpty (:) grp)
                       $ groupBy (\a b -> a.name == b.name)
                       $ sortWith jobName jobs
  where
    jobId     = \j -> j.id
    jobStatus = \j -> j.status
    jobName   = \j -> j.name
