using System;
using System.IO;
using Microsoft.Extensions.DependencyInjection;
using FluentMigrator.Runner;
using Microsoft.Extensions.Configuration;

namespace Migrations
{
    public static class MigratorConfig
    {


        public static string getCurrentPath()
        {
            return Directory.GetParent(Directory.GetCurrentDirectory()).FullName +
                   String.Format("\\{0}\\", ReflectionsHacks.getMigration().FullName);
        }

        public static string getSqlLocations()
        {
            return "/migration";
        }
    }
}