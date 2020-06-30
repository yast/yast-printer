# Copyright (c) [2020] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require_relative "./test_helper"
require_relative "../src/clients/printer_auto"

describe Yast::PrinterAutoClient do
  describe "#main" do
    let(:args) { ["Export"] }

    before do
      allow(Yast::WFM).to receive(:Args) { |i = nil| i ? args[i] : args }
      allow(subject).to receive(:ReadFileContent).with(/cupsd.conf/)
        .and_return("cupsd.conf content")
      allow(subject).to receive(:ReadFileContent).with(/client.conf/)
        .and_return("client.conf content")
    end

    describe "Export" do
      let(:enabled?) { true }

      before do
        allow(Yast::Printer).to receive(:enabled?).and_return(enabled?)
      end

      context "when the 'cups' service is enabled" do
        let(:enabled) { true }

        it "returns the content of CUPS configuration files" do
          expect(subject.main).to include(
            "cupsd_conf_content"  => {
              "file_contents" => "cupsd.conf content"
            },
            "client_conf_content" => {
              "file_contents" => "client.conf content"
            }
          )
        end
      end

      context "when the 'cups' service is disabled" do
        let(:enabled?) { false }

        it "returns an empty hash" do
          expect(subject.main).to eq({})
        end
      end
    end
  end
end
