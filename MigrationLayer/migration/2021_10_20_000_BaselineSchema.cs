using System;
using FluentMigrator;
using Migrations.@abstract;

namespace Migrations
{
    [Migration(2021_10_20_001, "Baseline schema")]
    public class BaselineSchema : SQLMigration
    {
        public override void Up()
        {
            ExecuteScript("/scripts/00-baseline_schema.sql");
        }

        public override void Down()
        {
            Delete.Schema("dbo");
        }
    }
}