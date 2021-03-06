{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE TypeFamilies  #-}

module Example02
where

--------------------------------------------------------------------------------
import           Control.Applicative
import qualified Control.Monad.State as State
--------------------------------------------------------------------------------
import qualified Data.Store as S hiding (insert, update, updateWithRawKey)
import           Data.Store (M, O, (.:), (.:.), (:.)(..), (.<), (.<=), (.>), (.>=), (./=), (.==), (.&&), (.||))
import           Data.Store.Storable as S
--------------------------------------------------------------------------------

data Content = Content
    { contentName :: String  
    , contentBody :: String  
    , contentTags :: [String]
    , contentRating :: Double
    }

type ContentID = Int

-- Content has one ID, only one content can have a given ID.
-- Content has one name, only one content can have a given name.
-- Content has one body, many contents can have the same content.
-- Content has many tags, many contents can have the same tag.
-- Content has one rating, many contents can have the same rating.

data ContentStoreTag = ContentStoreTag

type ContentStoreKRS = O         :. O      :. O      :. M      :. O
type ContentStoreIRS = O         :. O      :. M      :. M      :. M
type ContentStoreTS  = ContentID :. String :. String :. String :. Double
type ContentStore = S.Store ContentStoreTag ContentStoreKRS ContentStoreIRS ContentStoreTS Content
type ContentStoreKey = S.Key ContentStoreKRS ContentStoreTS
type ContentStoreSelection = S.Selection ContentStoreTag ContentStoreKRS ContentStoreIRS ContentStoreTS

instance Storable Content where
     type StoreKRS Content = ContentStoreKRS
     type StoreIRS Content = ContentStoreIRS
     type StoreTS  Content = ContentStoreTS

     key (Content cn cb cts cr) = 
         S.dimA .: S.dimO cn .: S.dimO cb .: S.dimM cts .:. S.dimO cr

sContentID :: (ContentStoreTag, S.N0)
sContentID = (ContentStoreTag, S.n0)

sContentName :: (ContentStoreTag, S.N1)
sContentName = (ContentStoreTag, S.n1)

sContentBody :: (ContentStoreTag, S.N2)
sContentBody = (ContentStoreTag, S.n2)

sContentTag :: (ContentStoreTag, S.N3)
sContentTag = (ContentStoreTag, S.n3)

sContentRating :: (ContentStoreTag, S.N4)
sContentRating = (ContentStoreTag, S.n4)

type Model = State.State ContentStore

insertContent :: Content -> Model (Maybe ContentID)
insertContent c = do
    res <- S.insert c <$> State.get
    case res of
        Just (cid :. _, new) -> State.put new >> return (Just cid)
        _ -> return Nothing

lookupBySelection :: ContentStoreSelection -> Model [Content]
lookupBySelection sel = go . S.lookup sel <$> State.get
    where
      go = map snd 

lookupByID :: ContentID -> Model (Maybe Content)
lookupByID cid = go . S.lookup (sContentID .== cid) <$> State.get
    where
      go [(_, c)] = Just c
      go _        = Nothing

deleteByID :: ContentID -> Model ()
deleteByID cid = deleteBySelection (sContentID .== cid) 

deleteBySelection :: ContentStoreSelection -> Model ()
deleteBySelection sel = State.modify $ S.delete sel

