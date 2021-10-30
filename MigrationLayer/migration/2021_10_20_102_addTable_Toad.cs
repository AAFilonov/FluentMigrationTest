using System;
using System.IO;
using FluentMigrator;
using Migrations.@abstract;

namespace Migrations
{
    [Migration(2021_10_20_102, "01 добавление таблицы Тест1")]
    public class addTableToad : SQLMigration
    {
        public override void Up()
        {
            ExecuteScript("/scripts/02-create-Table-Toad.sql");
        }
        public override void Down()
        {
            Delete.Table("Toad");
        }
    }
}