-- | Wire types for the MPFS HTTP API.
-- Field names use snake_case to match the JSON
-- format, enabling generic argonaut codecs.
module MPFS.Client.Types
  ( Hex
  , TokenId
  , StatusResponse
  , TokenState
  , PendingRequest
  , BootBody
  , InsertBody
  , DeleteBody
  , UpdateBody
  , RetractBody
  , EndBody
  , SubmitBody
  ) where

import Data.Maybe (Maybe)

-- | Hex-encoded bytestring.
type Hex = String

-- | Hex-encoded token identifier (asset name).
type TokenId = Hex

-- | @GET /status@ response.
type StatusResponse =
  { tip_slot :: Number
  , tip_block_id :: Hex
  , checkpoint_slot :: Maybe Number
  , checkpoint_block_id :: Maybe Hex
  }

-- | @GET /tokens/:id@ response.
type TokenState =
  { owner :: Hex
  , root :: Hex
  , max_fee :: Number
  , process_time :: Number
  , retract_time :: Number
  }

-- | @GET /tokens/:id/requests@ element.
type PendingRequest =
  { token :: TokenId
  , owner :: Hex
  , key :: Hex
  , operation :: String
  , value :: Maybe Hex
  , fee :: Number
  , submitted_at :: Number
  }

-- | @POST /tx/boot@ body.
type BootBody = { address :: Hex }

-- | @POST /tx/request/insert@ body.
type InsertBody =
  { token :: TokenId
  , key :: Hex
  , value :: Hex
  , address :: Hex
  }

-- | @POST /tx/request/delete@ body.
type DeleteBody =
  { token :: TokenId
  , key :: Hex
  , address :: Hex
  }

-- | @POST /tx/update@ body.
type UpdateBody =
  { token :: TokenId
  , address :: Hex
  }

-- | @POST /tx/retract@ body.
type RetractBody =
  { tx_id :: Hex
  , tx_ix :: Number
  , address :: Hex
  }

-- | @POST /tx/end@ body.
type EndBody =
  { token :: TokenId
  , address :: Hex
  }

-- | @POST /tx/submit@ body.
type SubmitBody = { tx :: Hex }
