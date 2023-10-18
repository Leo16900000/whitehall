FactoryBot.define do
  factory :generic_image_data, class: ImageData do
    file { image_fixture_file }

    trait(:jpg) do
      after(:build) do |image_data|
        image_data.assets << build(:asset, asset_manager_id: "asset_manager_id_original", variant: Asset.variants[:original], filename: "minister-of-funk.960x640.jpg")
        image_data.assets << build(:asset, asset_manager_id: "asset_manager_id_s960", variant: Asset.variants[:s960], filename: "s960_minister-of-funk.960x640.jpg")
        image_data.assets << build(:asset, asset_manager_id: "asset_manager_id_s712", variant: Asset.variants[:s712], filename: "s712_minister-of-funk.960x640.jpg")
        image_data.assets << build(:asset, asset_manager_id: "asset_manager_id_s630", variant: Asset.variants[:s630], filename: "s630_minister-of-funk.960x640.jpg")
        image_data.assets << build(:asset, asset_manager_id: "asset_manager_id_s465", variant: Asset.variants[:s465], filename: "s465_minister-of-funk.960x640.jpg")
        image_data.assets << build(:asset, asset_manager_id: "asset_manager_id_s300", variant: Asset.variants[:s300], filename: "s300_minister-of-funk.960x640.jpg")
        image_data.assets << build(:asset, asset_manager_id: "asset_manager_id_s216", variant: Asset.variants[:s216], filename: "s216_minister-of-funk.960x640.jpg")
      end
    end

    trait(:svg) do
      file { File.open(Rails.root.join("test/fixtures/images/test-svg.svg")) }

      after(:build) do |image_data|
        image_data.assets << build(:asset, asset_manager_id: "asset_manager_id", variant: Asset.variants[:original], filename: "test-svg.svg")
      end
    end
  end

  factory :image_data, parent: :generic_image_data, traits: [:jpg]
  factory :image_data_for_svg, parent: :generic_image_data, traits: [:svg]
  factory :image_data_with_no_assets, parent: :generic_image_data
end
