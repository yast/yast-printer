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

Yast.import "Printer"

describe Yast::Printer do
  describe "#enabled?" do
    let(:service) { instance_double(Yast2::SystemService, start_mode: start_mode) }

    before do
      allow(Yast2::SystemService).to receive(:find).with("cups").and_return(service)
    end

    context "if cups is started on boot" do
      let(:start_mode) { :on_boot }

      it "returns true" do
        expect(subject.enabled?).to eq(true)
      end
    end

    context "if cups is started on demand" do
      let(:start_mode) { :on_demand }

      it "returns true" do
        expect(subject.enabled?).to eq(true)
      end
    end

    context "if cups is disabled" do
      let(:start_mode) { :manual }

      it "returns false" do
        expect(subject.enabled?).to eq(false)
      end
    end

    context "if cups service does not exist" do
      let(:service) { nil }

      it "returns false" do
        expect(subject.enabled?).to eq(false)
      end
    end
  end
end
