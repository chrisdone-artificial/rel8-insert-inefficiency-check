{-# LANGUAGE DeriveAnyClass, PolyKinds #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE StandaloneKindSignatures #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE ImportQualifiedPost #-}

module Main where

import Hasql.Session qualified as Hasql
import Hasql.Connection qualified as Hasql

import qualified Rel8

import GHC.Generics (Generic)
import qualified Data.ByteString as BS
import Data.Kind (Type)

-- Define the database schema with just a content field
data FileSchema f = FileSchema
  { fileContent :: Rel8.Column f BS.ByteString
  }
  deriving stock (Generic)
  deriving anyclass (Rel8.Rel8able)

-- Configure the table mapping
fileSchema :: Rel8.TableSchema (FileSchema Rel8.Name)
fileSchema = Rel8.TableSchema
  { name = "files"
  , columns = FileSchema
      { fileContent = "content"
      }
  }

-- Helper to create a file record for insertion
mkFileInsert :: BS.ByteString -> FileSchema Rel8.Result
mkFileInsert fContent = FileSchema
  { fileContent = fContent
  }

-- Main demo function
main :: IO ()
main = do
  -- Connection settings (adjust for your database)
  let connSettings = Hasql.settings "172.17.0.3" 5432 "postgres" "password" "testdb"

  -- Acquire connection
  connResult <- Hasql.acquire connSettings
  case connResult of
    Left err -> putStrLn $ "Connection failed: " ++ show err
    Right conn -> do
      putStrLn "Connected to database"

      -- Create sample binary data
      let sampleContent = "Hello, this is sample file content!"
      let fileData = BS.pack $ map (fromIntegral . fromEnum) sampleContent

      -- Insert the file
      result <- Hasql.run (insertFile fileData) conn
      case result of
        Left err -> putStrLn $ "Insert failed: " ++ show err
        Right () -> putStrLn "File inserted successfully!"

-- Insert function using Rel8
insertFile :: BS.ByteString -> Hasql.Session ()
insertFile fContent = do
  let run = Rel8.prepared Rel8.run_
  Hasql.statement (mkFileInsert fContent) $
    run $ \f -> Rel8.insert $ Rel8.Insert
    { into = fileSchema
    , rows = Rel8.values [f]
    , onConflict = Rel8.Abort
    , returning = Rel8.NoReturning
    }
