require 'spec_helper'

RSpec.describe OpenStax::Content::BookPart do
  let(:book_hashes) do
    [
      {
        'id' => '93e2b09d-261c-4007-a987-0b3062fe154b',
        'contents' => [
          { 'id' => 'subcol',
            'contents' => [
              { 'id' => '1bb611e9-0ded-48d6-a107-fbb9bd900851@2',
                'title' => 'Introduction' },
              { 'id' => '95e61258-2faf-41d4-af92-f62e1414175a@3',
                'title' => 'Force'},
              { 'id' => '640e3e84-09a5-4033-b2a7-b7fe5ec29dc6@3',
                'title' => "Newton's First Law of Motion: Inertia"}
            ],
            'title' => "Forces and Newton's Laws of Motion" }
        ],
        'title' => 'Physics'
      },
      {
        'id' => 'subcol',
        'contents' => [
          { 'id' => '1bb611e9-0ded-48d6-a107-fbb9bd900851@2',
            'title' => 'Introduction' },
          { 'id' => '95e61258-2faf-41d4-af92-f62e1414175a@3',
            'title' => 'Force'},
          { 'id' => '640e3e84-09a5-4033-b2a7-b7fe5ec29dc6@3',
            'title' => "Newton's First Law of Motion: Inertia"}
        ],
        'title' => "Forces and Newton's Laws of Motion"
      }
    ]
  end
  let(:expected_part_classes) { [ [ described_class ], [ OpenStax::Content::Page ] * 3 ] }

  it 'provides info about the book part for the given hash 'do
    book_hashes.each do |book_hash|
      book_part = described_class.new hash: book_hash
      expect(book_part.hash).not_to be_empty
      expect(book_part.title).to eq book_hash['title']
      expect(book_part.contents).not_to be_empty
      expect(book_part.parts).not_to be_empty
    end
  end

  it 'can retrieve its children parts' do
    book_hashes.each_with_index do |book_hash, index|
      book_part = described_class.new hash: book_hash
      expect(book_part.parts.map(&:class)).to eq expected_part_classes[index]
    end
  end

  it 'can recursively return all of its pages' do
    book_hashes.each_with_index do |book_hash, index|
      book_part = described_class.new hash: book_hash
      expect(book_part.all_pages.map(&:class)).to eq [ OpenStax::Content::Page ] * 3
    end
  end
end
