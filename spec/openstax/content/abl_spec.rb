require 'spec_helper'
require 'vcr_helper'

RSpec.describe OpenStax::Content::Abl, vcr: VCR_OPTS do
  subject(:abl)        { described_class.new }
  let(:approved_books) { abl.approved_books archive: MINI_BOOK_ARCHIVE }

  it 'can generate a list of approved books from the ABL' do
    expect(approved_books).not_to be_empty

    approved_books.each { |book| expect(book).to be_a(OpenStax::Content::Book) }
  end
end
