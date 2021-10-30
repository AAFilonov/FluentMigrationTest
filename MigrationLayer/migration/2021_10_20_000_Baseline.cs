using System;
using FluentMigrator;

namespace Migrations
{
  [Migration(2021_10_20_000,"Initial state")]
    public class Baseline : Migration
    {
        public override void Up()
        {
            Create.Table("Log")
                .WithColumn("Id").AsInt64().PrimaryKey().Identity()
                .WithColumn("Text").AsString();
        }

        public override void Down()
        {
            Delete.Table("Log");
        }
    }
}