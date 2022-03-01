require 'spec_helper'
require 'vcr_helper'

RSpec.describe OpenStax::Content::Abl, vcr: VCR_OPTS do
  subject(:abl)        { described_class.new }
  let(:approved_books) { abl.approved_books archive: MINI_BOOK_ARCHIVE }

  it 'can generate a list of approved books from the ABL' do
    expect(approved_books).not_to be_empty

    approved_books.each { |book| expect(book).to be_a(OpenStax::Content::Book) }
  end

  it "can return the ABL's digest" do
    expect(abl.digest).to eq '860d671a8364af86cda7bf29d98899d4df567f60e8b6f26297adfac1122e045c'
  end
end
