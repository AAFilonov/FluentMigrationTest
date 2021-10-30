using System;
using System.Collections.Generic;
using System.IO;
using System.Reflection;

namespace Migrations
{
    public class ReflectionsHacks
    {
        public static Assembly getMigration()
        {
            string path = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);
            var name = Assembly.GetCallingAssembly().GetName().Name;
            foreach (string dll in Directory.GetFiles(path, name+".dll"))
                return Assembly.LoadFile(dll);

            throw new Exception(name+".dll not found!");
        }

        public static Assembly[] getAssemblies()
        {
            var migrationsAssembly = getMigration();
            var types = migrationsAssembly.DefinedTypes;
            List<Assembly> assemblies = new List<Assembly>();
            foreach (var type in types)
            {
                assemblies.Add(type.Assembly);
            }
            
            return  assemblies.ToArray();
        }
    }
}