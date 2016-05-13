module Pipes.Core (
  -- * Proxy Monad Transformer
    runEffect

  -- * Categories

  -- ** Respond
  , respond
  , composeResponse'
  , (/>/)
  , composeResponse
  , (//>)

  -- ** Request
  , request
  , composeRequest'
  , (\>\)
  , composeRequest
  , (>\\)

  -- ** Push
  , push
  , composePush
  , (>~>)
  , composePush'
  , (>>~)

  -- ** Pull
  , pull
  , composePull
  , (>+>)
  , composePull'
  , (+>>)

  -- ** Reflect
  , reflect

  -- * Concrete Type Synonyms
  , Effect
  , Producer
  , Pipe
  , Consumer
  , Client
  , Server

  -- * Flipped operators
  , flippedComposeResponse'
  , (\<\)
  , flippedComposeRequest'
  , (/</)
  , flippedComposePush
  , (<~<)
  , flippedComposePush'
  , (~<<)
  , flippedComposePull
  , (<+<)
  , flippedComposePull'
  , (<<+)
  , flippedComposeResponse
  , (<\\)
  , flippedComposeRequest
  , (//<)

  -- * Re-exports
  , module I
  ) where

import Prelude
import Pipes.Internal
import Pipes.Internal (Proxy (), X(), closed) as I

type Effect      = Proxy X Unit Unit X
type Producer b  = Proxy X Unit Unit b
type Pipe a b    = Proxy Unit a Unit b
type Consumer a  = Proxy Unit a Unit X

type Client a' a = Proxy a' a Unit X
type Server b' b = Proxy X Unit b' b

runEffect :: forall m r. Monad m => Effect m r -> m r
runEffect = go
  where
    go p = case p of
        Request v _ -> closed v
        Respond v _ -> closed v
        M       m   -> m >>= go
        Pure    r   -> return r

respond :: forall m a a' x x'. Monad m => a -> Proxy x' x a' a m a'
respond a = Respond a Pure

composeResponse
    :: forall m x x' a' b b' c c'
     . Monad m
    =>       Proxy x' x b' b m a'
    -> (b -> Proxy x' x c' c m b')
    ->       Proxy x' x c' c m a'
composeResponse p0 fb = go p0
  where
    go p = case p of
        Request x' fx  -> Request x' (go <<< fx)
        Respond b  fb' -> fb b >>= go <<< fb'
        M          m   -> M (go <$> m)
        Pure       a   -> Pure a

composeResponse'
    :: forall m x x' a a' b b' c c'
     . Monad m
    => (a -> Proxy x' x b' b m a')
    -> (b -> Proxy x' x c' c m b')
    -> (a -> Proxy x' x c' c m a')
composeResponse' fa fb a = fa a //> fb

infixl 3 composeResponse  as //>
infixr 4 composeResponse' as />/

request :: forall a a' y y' m. Monad m => a' -> Proxy a' a y' y m a
request a' = Request a' Pure

composeRequest
  :: forall a a' b b' c y y' m
   . Monad m
  => (b' -> Proxy a' a y' y m b)
  ->        Proxy b' b y' y m c
  ->        Proxy a' a y' y m c
composeRequest fb' p0 = go p0
  where
    go p = case p of
        Request b' fb  -> fb' b' >>= go <<< fb
        Respond x  fx' -> Respond x (go <<< fx')
        M          m   -> M (go <$> m)
        Pure       a   -> Pure a

composeRequest'
  :: forall a a' b b' c c' y y' m
   . Monad m
  => (b' -> Proxy a' a y' y m b)
  -> (c' -> Proxy b' b y' y m c)
  -> (c' -> Proxy a' a y' y m c)
composeRequest' fb' fc' c' = fb' >\\ fc' c'

infixl 5 composeRequest  as >\\
infixr 4 composeRequest' as \>\


pull :: forall a a' m r. Monad m => a' -> Proxy a' a a' a m r
pull = go
  where
    go a' = Request a' (\a -> Respond a go)

composePull
    :: forall a a' b b' c c' _c' m r
     . Monad m
    => ( b' -> Proxy a' a b' b m r)
    -> (_c' -> Proxy b' b c' c m r)
    -> (_c' -> Proxy a' a c' c m r)
composePull fb' fc' c' = fb' +>> fc' c'

composePull'
    :: forall a a' b b' c c' m r
     . Monad m
    => (b' -> Proxy a' a b' b m r)
    ->        Proxy b' b c' c m r
    ->        Proxy a' a c' c m r
composePull' fb' p = case p of
    Request b' fb  -> fb' b' >>~ fb
    Respond c  fc' -> Respond c ((fb' +>> _) <<< fc')
    M          m   -> M ((fb' +>> _) <$> m)
    Pure       r   -> Pure r

infixr 6 composePull' as +>>
infixl 7 composePull  as >+>

push :: forall a a' m r. Monad m => a -> Proxy a' a a' a m r
push = go
  where
    go a = Respond a (\a' -> Request a' go)

composePush
    :: forall _a a a' b b' c c' m r
     . Monad m
    => (_a -> Proxy a' a b' b m r)
    -> ( b -> Proxy b' b c' c m r)
    -> (_a -> Proxy a' a c' c m r)
composePush fa fb a = fa a >>~ fb

composePush'
    :: forall a a' b b' c c' m r
     . Monad m
    =>       Proxy a' a b' b m r
    -> (b -> Proxy b' b c' c m r)
    ->       Proxy a' a c' c m r
composePush' p fb = case p of
    Request a' fa  -> Request a' (\a -> fa a >>~ fb)
    Respond b  fb' -> fb' +>> fb b
    M          m   -> M (m >>= \p' -> return (p' >>~ fb))
    Pure       r   -> Pure r

infixl 7 composePush' as >>~
infixr 8 composePush  as >~>

reflect
  :: forall a a' b b' m r
   . Monad m
  => Proxy a' a b' b m r -> Proxy b b' a a' m r
reflect = go
  where
    go p = case p of
        Request a' fa  -> Respond a' (go <<< fa)
        Respond b  fb' -> Request b  (go <<< fb')
        M          m   -> M (go <$> m)
        Pure    r      -> Pure r

-- | Equivalent to ('/>/') with the arguments flipped
flippedComposeResponse'
    :: forall m x x' a a' b b' c c'
     . Monad m
    => (b -> Proxy x' x c' c m b')
    -> (a -> Proxy x' x b' b m a')
    -> (a -> Proxy x' x c' c m a')
flippedComposeResponse' p1 p2 = p2 />/ p1

infixl 4 flippedComposeResponse' as \<\

-- | Equivalent to ('\>\') with the arguments flipped
flippedComposeRequest'
  :: forall a a' b b' c c' y y' m
   . Monad m
    => (c' -> Proxy b' b y' y m c)
    -> (b' -> Proxy a' a y' y m b)
    -> (c' -> Proxy a' a y' y m c)
flippedComposeRequest' p1 p2 = p2 \>\ p1

infixr 4 flippedComposeRequest' as /</

-- | Equivalent to ('>~>') with the arguments flipped
flippedComposePush
    :: forall a a' b b' c c' m r
     . Monad m
    => (b -> Proxy b' b c' c m r)
    -> (a -> Proxy a' a b' b m r)
    -> (a -> Proxy a' a c' c m r)
flippedComposePush p1 p2 = p2 >~> p1

infixl 8 flippedComposePush as <~<

-- | Equivalent to ('>+>') with the arguments flipped
flippedComposePull
    :: forall a a' b b' c c' m r
     . Monad m
    => (c' -> Proxy b' b c' c m r)
    -> (b' -> Proxy a' a b' b m r)
    -> (c' -> Proxy a' a c' c m r)
flippedComposePull p1 p2 = p2 >+> p1

infixr 7 flippedComposePull as <+<

-- | Equivalent to ('//>') with the arguments flipped
flippedComposeResponse
    :: forall m x x' a' b b' c c'
     . Monad m
    => (b -> Proxy x' x c' c m b')
    ->       Proxy x' x b' b m a'
    ->       Proxy x' x c' c m a'
flippedComposeResponse f p = p //> f

infixr 3 flippedComposeResponse as <\\

-- | Equivalent to ('>\\') with the arguments flipped
flippedComposeRequest
  :: forall a a' b b' c y y' m
   . Monad m
    =>        Proxy b' b y' y m c
    -> (b' -> Proxy a' a y' y m b)
    ->        Proxy a' a y' y m c
flippedComposeRequest p f = f >\\ p

infixl 4 flippedComposeRequest as //<

-- | Equivalent to ('>>~') with the arguments flipped
flippedComposePush'
    :: forall a a' b b' c c' m r
     . Monad m
    => (b  -> Proxy b' b c' c m r)
    ->        Proxy a' a b' b m r
    ->        Proxy a' a c' c m r
flippedComposePush' k p = p >>~ k

infixr 7 flippedComposePush' as ~<<

-- | Equivalent to ('+>>') with the arguments flipped
flippedComposePull'
    :: forall a a' b b' c c' m r
     . Monad m
    =>         Proxy b' b c' c m r
    -> (b'  -> Proxy a' a b' b m r)
    ->         Proxy a' a c' c m r
flippedComposePull' k p = p +>> k

infixl 6 flippedComposePull' as <<+
