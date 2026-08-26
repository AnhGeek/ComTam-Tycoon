// Polyfill required for C# 9 `init` accessors and records on netstandard2.1.
// Unity supplies its own copy, so this is excluded from the Unity asmdef via
// the COMTAM_UNITY define. Do not delete: the .NET build needs it.
#if !COMTAM_UNITY
namespace System.Runtime.CompilerServices
{
    internal static class IsExternalInit { }
}
#endif
