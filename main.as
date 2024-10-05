class Match
{
    CGameCtnGhost@ Ghost = null;
    CSystemFidFile@ GhostFile = null;
    string GhostKind = "";
    string MapUID = "";
    string GhostFileName = "";
    string GhostTime = "";
    int GhostTimeInt = -1;
    int MapNum = 0;
    int idx = 0;

    Match(){}

    string ToString()
    {
        return GhostFileName + " -> #" + MapNum + " (" + GhostTime + ")";
    }

    string get_GhostSolo()
    {
        return GetSoloKind(GhostKind);
    }
}

const string GhostFinderLogo = "\\$d3f" + Icons::Book + " \\$z";

UI::Font@ Monospace;

array<string> Final = {};
array<Match> Matches = {};

bool IsDownloadingEmptyReplay = false;
bool RenderMatchModifications = false;
Match@ CurrentActiveMatch = null;

bool IsConvertingReplay = false;

[Setting hidden]
bool IsVisible = true;

[Setting min=10 max=200 name="Match limit for warning" category="Settings"]
uint S_WarnFewGhosts = 200;

[Setting hidden]
bool IsEmptyReplayInstalled = false;

bool MapsHaveLoaded = false;
bool Done = false;
bool IsUIDExportFinished = false;

bool EnableFilter = false;
bool filter = false;

int FilterMapNumber = 1;
int fmapnum = 1;

uint ProfileFolderNotFoundFailsafe = 0;
uint MapsGhostsFolderNotFoundFailsafe = 0;

CSystemFidsFolder@ ProfileFolder = null;
CSystemFidsFolder@ MapsGhostsFolder = null;

void RenderMenu() 
{
    if (UI::MenuItem(GhostFinderLogo + "GhostFinder", "", IsVisible)) {
        IsVisible = !IsVisible;
    } 
}

void Render()
{
    if (!IsVisible) return;
    if (IsConvertingReplay)
    {
        auto App = cast<CGameCtnApp>(GetApp());
        auto Editor = App.Editor;
        if (Editor !is null)
        {
            auto ReplayEditor = cast<CGameCtnMediaTracker>(Editor);
            if (ReplayEditor !is null)
            {
                auto Ghost = GetGhostFromEditor(ReplayEditor);
                if (Ghost !is null)
                {
                    Dev::SetOffset(Ghost, 0x50, cast<CMwNod>(CurrentActiveMatch.Ghost));
                    IsConvertingReplay = false;
                }
            }
        }
    }
    UI::PushFont(Monospace);
    if (RenderMatchModifications)
    {
        if (CurrentActiveMatch !is null)
        {
            if (UI::Begin(GhostFinderLogo + "Modify Ghost (GhostFinder)", RenderMatchModifications))
            {
                RenderMatchMod();
                UI::End();
            }
        }
    }
    if (UI::Begin("\\$d3f" + Icons::Book + " \\$zGhostFinder", IsVisible, UI::WindowFlags::NoCollapse))
    {
        UI::Text(!IsUIDExportFinished ? "Please wait..." : "Done!");

        if (!IsUIDExportFinished) UI::Separator();

        if (IsUIDExportFinished)
        {
            UI::SameLine();
            UI::Text("Total " + Matches.Length + " Ghost" + (Matches.Length == 1 ? "" : "s") + " found.");
            UI::Separator();
            if (Matches.Length < S_WarnFewGhosts)
            {
                UI::Text("Only a few matches were found.\nPlease wait for the game to load during bootup and reload\nif this behaviour is unexpected.\nYou can also force load all of the ghosts in your MapsGhosts folder.");
                UI::Separator();
            }
        }

        if (UI::Button("Reload"))
        {
            Done = false;
            IsUIDExportFinished = false;
        }
        UI::SameLine();
        if (UI::Button("Force load all ghosts"))
        {
            ForceLoadAllGhosts();
        }
        UI::Separator();

        EnableFilter = UI::Checkbox("Find ghost by map number", filter);
        filter = EnableFilter;

        if (!EnableFilter) UI::Separator();

        if (EnableFilter)
        {
            if (fmapnum > 200)
            {
                fmapnum = 200;
            }
            if (fmapnum < 1)
            {
                fmapnum = 1;
            }
            FilterMapNumber = UI::InputInt("Map number", fmapnum);
            fmapnum = FilterMapNumber;

            UI::Separator();
            for (uint i = 0; i < Matches.Length; i++)
            {
                auto Match = Matches[i];
                if (Match.MapNum == fmapnum) RenderMatch(Match);
            }
        }
        else
        {
            for (uint i = 0; i < Matches.Length; i++)
            {
                auto Match = Matches[i];
                RenderMatch(Match);
            }
        }
        UI::End();
    }
    UI::PopFont();
}

void Main()
{
    Fids::UpdateTree(Fids::GetUserFolder("Replays"));
    IsEmptyReplayInstalled = Fids::GetUser("Replays/Replays/EmptyReplay.Replay.Gbx") !is null;
    @Monospace = @UI::LoadFont("DroidSansMono.ttf");
    while (true)
    {
        LoadMapsAndGhosts();
        yield();
    }
}

void LoadMapsAndGhosts()
{
    if (Done) return;
    Matches = {};
    string MapStr = "001";
    while (!MapsHaveLoaded)
    {
        string Location = MapToPath(MapStr);

        auto MapFid = Fids::GetUser("Maps/" + Location);
        if (MapFid !is null)
        {
            MapsHaveLoaded = true;
            break;
        }
        yield();
    }
    for (uint i = 0; i < 200; i++)
    {
        string Location = MapToPath(MapStr);

        auto MapFid = Fids::GetUser("Maps/" + Location);
        auto MapNod = Fids::Preload(MapFid);
        if (MapNod is null)
        {
            warn("MapNod is null!");
            MapStr = NextMap(MapStr);
            continue;
        }
        auto Map = cast<CGameCtnChallenge>(MapNod);
        if (Map is null)
        {
            warn("Map is null!");
            MapStr = NextMap(MapStr);
            continue;
        }

        Final.InsertLast(Map.EdChallengeId);
        MapStr = NextMap(MapStr);
        yield();
    }
    auto UserFolder = Fids::GetUserFolder("");
    while (ProfileFolder is null)
    {
        for (uint i = 0; i < UserFolder.Trees.Length; i++)
        {
            auto Folder = cast<CSystemFidsFolder>(UserFolder.Trees[i]);
            if (Regex::IsMatch(Folder.DirName, ".{8}-.{4}-.{4}-.{4}-.{12}"))
            {
                @ProfileFolder = @Folder;
                break;
            }
        }
        if (ProfileFolder is null and ProfileFolderNotFoundFailsafe < 10) 
        {
            warn("ProfileFolder not found, retrying.");
            ProfileFolderNotFoundFailsafe++;
        }
        else if (ProfileFolder is null and ProfileFolderNotFoundFailsafe == 10)
        {
            warn("ProfileFolder not found for 10 consecutive frames, last warning.");
            ProfileFolderNotFoundFailsafe++;
        }
        yield();
    }
    while (MapsGhostsFolder is null)
    {
        for (uint i = 0; i < ProfileFolder.Trees.Length; i++)
        {
            auto Folder = cast<CSystemFidsFolder>(ProfileFolder.Trees[i]);
            if (tostring(Folder.DirName) == "MapsGhosts")
            {
                @MapsGhostsFolder = @Folder;
                break;
            }
        }
        if (MapsGhostsFolder is null and MapsGhostsFolderNotFoundFailsafe < 10) 
        {
            warn("MapsGhosts Folder not found, retrying.");
            MapsGhostsFolderNotFoundFailsafe++;
        }
        else if (MapsGhostsFolder is null and MapsGhostsFolderNotFoundFailsafe == 10)
        {
            warn("MapsGhosts Folder not found for 10 consecutive frames, last warning.");
            MapsGhostsFolderNotFoundFailsafe++;
        }
        yield();
    }
    for (uint i = 0; i < MapsGhostsFolder.Leaves.Length; ++i)
    {
        auto File = cast<CSystemFidFile>(MapsGhostsFolder.Leaves[i]);
        auto Nod = Fids::Preload(File);
        if (Nod is null) { error(File.FileName + " is not Nod."); continue; }
        auto Ghost = cast<CGameCtnGhost>(Nod);
        if (Ghost is null) { warn(File.FileName + " is not Ghost."); continue; }
        string MapUIDFromGhost = GetMapUIDFromGhost(Ghost);
        int idx = Final.Find(MapUIDFromGhost);
        if (idx >= 0)
        {
            Match match = Match();
            match.GhostKind = Ghost.RecordingContext;
            match.GhostFileName = File.FileName;
            match.MapUID = MapUIDFromGhost;
            match.MapNum = idx + 1;
            match.idx = idx;
            @match.GhostFile = @File;
            match.GhostTime = Time::Format(Ghost.RaceTime);
            match.GhostTimeInt = Ghost.RaceTime;
            @match.Ghost = Ghost;
            Matches.InsertLast(match);
        }
        yield();
    }
    Done = true;
    IsUIDExportFinished = true;
}
