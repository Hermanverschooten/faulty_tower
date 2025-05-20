defmodule FaultyTower.OrganizationTest do
  alias FaultyTower.Organization
  use FaultyTower.DataCase

  test "create organization" do
    assert {:ok, org} = Organization.create("test")
    assert org.name == "test"
  end

  test "No duplicated" do
    assert {:ok, _org} = Organization.create("test")
    assert {:error, changeset} = Organization.create("test")
    assert changeset.errors != []
  end
end
