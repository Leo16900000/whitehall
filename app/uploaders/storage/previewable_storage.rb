class Storage::PreviewableStorage < CarrierWave::Storage::Abstract
  def store!(carrierwave_file)
    original_file = carrierwave_file.to_file
    temporary_location = Whitehall::AssetManagerStorage::TempStorage.store!(original_file)

    logger.info("Saving to Asset Manager for model #{uploader.model.class} with ID #{uploader.model.id}")

    asset_variant = uploader.version_name ? Asset.variants[uploader.version_name] : Asset.variants[:original]
    asset_params = { assetable_id: uploader.model.id, asset_variant:, assetable_type: uploader.model.class.to_s }.deep_stringify_keys

    AssetManagerCreateAssetWorker.perform_async(temporary_location, asset_params, false, nil, nil, uploader.model.auth_bypass_ids)

    Whitehall::AssetManagerStorage::File.new(uploader.store_path(::File.basename(original_file)), uploader.model, uploader.version_name)
  end

  def retrieve!(identifier)
    asset_path = uploader.store_path(identifier)
    Whitehall::AssetManagerStorage::File.new(asset_path, uploader.model, uploader.version_name)
  end
end
