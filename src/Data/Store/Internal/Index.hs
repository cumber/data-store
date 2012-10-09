{-# LANGUAGE GADTs               #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Data.Store.Internal.Index
( Index(..)
, ObjectID
, insertDimension
, insertDimensionInternal
, split
, delete
) where

--------------------------------------------------------------------------------
import qualified Unsafe.Coerce as Unsafe
--------------------------------------------------------------------------------
import qualified Data.IntSet as IS
import qualified Data.Map    as M
import qualified Data.List   as L
--------------------------------------------------------------------------------
import qualified Data.Store.Key          as I
import qualified Data.Store.Internal.Key as I
--------------------------------------------------------------------------------

moduleName :: String
moduleName = "Data.Store.Internal.Index"

data Index where
    Index
        :: Ord k
        => M.Map k IS.IntSet
        -> Index
    
    IndexAuto
        :: (Ord k, I.Auto k)
        => M.Map k IS.IntSet
        -> k
        -> Index

type ObjectID = Int

-- |
-- WARNING: Uses 'Unsafe.Coerce.unsafeCoerce' internally. Assumes, that the
-- passed key of type 'k' is of the same type as the key the index is based
-- on.
split :: Ord k => k -> Index -> (IS.IntSet, IS.IntSet)
split dkey dindex =
    case dindex of
        (Index m) -> go m
        (IndexAuto m _) -> go m
    where
      go :: Ord k => M.Map k IS.IntSet -> (IS.IntSet, IS.IntSet)
      go m = mapTuple (IS.unions . map snd . M.toList) $ M.split (Unsafe.unsafeCoerce dkey) m

      -- | join (***)
      mapTuple :: (a -> b) -> (a, a) -> (b, b)
      mapTuple f (x, y) = (f x, f y) 

-- |
-- WARNING: Uses 'Unsafe.Coerce.unsafeCoerce' internally. Assumes, that the
-- passed key of type 'k' is of the same type as the key the index is based
-- on.
insertDimension :: I.Dimension k dt
                -> ObjectID           
                -> Index
                -> (Index, I.DimensionInternal k dt)
insertDimension (I.Dimension ks) oid (Index imap) =
    (Index $ L.foldl' go imap ks, I.IDimension ks)
    where
      go acc k = M.insertWith IS.union (Unsafe.unsafeCoerce k) (IS.singleton oid) acc
insertDimension (I.Dimension _) _ _ =
    error $ moduleName ++ ".insertDimension: non-matching dimension and dimension index constructors." 
insertDimension I.DimensionAuto oid (IndexAuto imap inext) = 
    (IndexAuto inew $ I.nextValue inext, I.IDimensionAuto $ Unsafe.unsafeCoerce inext)
    where
      inew  = M.insertWith IS.union (Unsafe.unsafeCoerce inext) (IS.singleton oid) imap
insertDimension I.DimensionAuto _ _ =
    error $ moduleName ++ ".insertDimension: non-matching dimension and dimension index constructors."


-- |
-- WARNING: Uses 'Unsafe.Coerce.unsafeCoerce' internally. Assumes, that the
-- passed key of type 'k' is of the same type as the key the index is based
-- on.
insertDimensionInternal :: I.DimensionInternal a dt
                        -> ObjectID            
                        -> Index
                        -> Index
insertDimensionInternal (I.IDimension ks) oid (Index imap) =
    Index $ L.foldl' go imap ks
    where
      go acc k = M.insertWith IS.union (Unsafe.unsafeCoerce k) (IS.singleton oid) acc
insertDimensionInternal (I.IDimension _) _ _ =
    error $ moduleName ++ ".insertDimension: non-matching dimension and dimension index constructors." 
insertDimensionInternal (I.IDimensionAuto k) oid (IndexAuto imap inext) = 
    IndexAuto inew inext
    where
      inew = M.insertWith IS.union (Unsafe.unsafeCoerce k) (IS.singleton oid) imap
insertDimensionInternal (I.IDimensionAuto _) _ _ =
    error $ moduleName ++ ".insertDimension: non-matching dimension and dimension index constructors."

-- |
-- WARNING: Uses 'Unsafe.Coerce.unsafeCoerce' internally. Assumes, that the
-- passed key of type 'k' is of the same type as the key the index is based
-- on.
delete :: [k]
       -> Index
       -> Index
delete [] x = x
delete [k] (Index imap) = Index $ M.delete (Unsafe.unsafeCoerce k) imap
delete [k] (IndexAuto imap inext) = IndexAuto (M.delete (Unsafe.unsafeCoerce k) imap) inext
delete ks (Index imap) = Index $ L.foldl' (\acc k -> M.delete (Unsafe.unsafeCoerce k) acc) imap ks
delete ks (IndexAuto imap inext) = IndexAuto (L.foldl' (\acc k -> M.delete (Unsafe.unsafeCoerce k) acc) imap ks) inext

