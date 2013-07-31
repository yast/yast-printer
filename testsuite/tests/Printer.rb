# encoding: utf-8

module Yast
  class PrinterClient < Client
    def main
      # testedfiles: Printer.ycp

      Yast.include self, "testsuite.rb"
      TESTSUITE_INIT([], nil)

      Yast.import "Printer"

      DUMP("Printer::Modified")
      TEST(lambda { Printer.Modified }, [], nil)

      nil
    end
  end
end

Yast::PrinterClient.new.main
