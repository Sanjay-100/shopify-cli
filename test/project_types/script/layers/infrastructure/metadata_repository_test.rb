# frozen_string_literal: true

require "project_types/script/test_helper"

describe Script::Layers::Infrastructure::MetadataRepository do
  include TestHelpers::FakeFS
  let(:instance) { Script::Layers::Infrastructure::MetadataRepository.new(ctx: ctx) }
  let(:ctx) { TestHelpers::FakeContext.new }

  describe ".get_metadata" do
    subject { instance.get_metadata }

    describe "when metadata file is present and valid" do
      let(:major_version) { "1" }
      let(:minor_version) { "0" }
      let(:metadata_file_location) { "metadata.json" }
      let(:metadata_json) do
        JSON.dump(
          {
            schemaVersions: {
              example: { major: major_version, minor: minor_version },
            },
          },
        )
      end

      before do
        File.write(metadata_file_location, metadata_json)
      end

      it "should return a proper metadata object" do
        assert_instance_of Script::Layers::Domain::Metadata, subject
        assert_equal major_version, subject.schema_major_version
        assert_equal minor_version, subject.schema_minor_version
      end

      describe "when filename argument is provided" do
        let(:metadata_file_location_argument) { "build/metadata.json" }
        subject { instance.get_metadata(metadata_file_location_argument) }

        it "should read that file" do
          File
            .expects(:read)
            .with(metadata_file_location_argument)
            .once.returns(metadata_json)
          ctx
            .expects(:file_exist?)
            .with(metadata_file_location_argument)
            .once
            .returns(true)
          subject
        end
      end
    end

    describe "when metadata file is missing" do
      it "should raise an exception" do
        assert_raises(Script::Layers::Domain::Errors::MetadataNotFoundError) do
          subject
        end
      end
    end
  end
end
