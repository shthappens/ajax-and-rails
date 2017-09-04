require 'rails_helper'

RSpec.describe Genre, type: :model do
  it { should have_many(:videos) }

  context "name" do
    subject { Genre.new(name: "Horror") }
    it { should validate_presence_of(:name) }
    it { should validate_uniqueness_of(:name) }
  end
end
