require 'spec_helper'

describe Compiler do
  pending
end

describe Compiler::File do
  describe "#content" do
    it "should preserve BOM at the beginning of the IO" do
      # Calling io.string and io.read are not identical. This test ensures that the BOM
      # data is preserved when pulling the information out of the IO.
      io  = StringIO.new
      bom = [0xFF, 0xFE]
      bom.each { |b| io.putc b }
      file     = Compiler::File.new(io, 'UTF-16LE', 'foo.bar', "application/x-gzip; charset=utf-16le")
      content = file.content
      expect(content.bytes.to_a[0]).to eq(bom[0])
      expect(content.bytes.to_a[1]).to eq(bom[1])
    end
  end
end