CGameCtnChallenge@ MapToChallenge(const string &in map)
{
    return cast<CGameCtnChallenge>(Fids::Preload(Fids::GetUser("Maps/" + MapToPath(map))));
}

string MapToPath(const string &in map)
{
    string MapPath = "";
    int MapNumber = Text::ParseInt(map);

    int Color;
    
    if (MapNumber <= 40)
    {
        Color = 1;
    }
    else if (MapNumber <= 80)
    {
        Color = 2;
    }
    else if (MapNumber <= 120)
    {
        Color = 3;
    }
    else if (MapNumber <= 160)
    {
        Color = 4;
    }
    else if (MapNumber <= 200)
    {
        Color = 5;
    }

    string ColorName = "";

    switch (Color)
    {
        case 1:
            ColorName = "White";
            break;
        case 2:
            ColorName = "Green";
            break;
        case 3:
            ColorName = "Blue";
            break;
        case 4:
            ColorName = "Red";
            break;
        case 5:
            ColorName = "Black";
            break;
    }

    string Flag = "0" + Color + "_" + ColorName;

    string Environment = "";
    
    int EnviNumber = MapNumber % 40;

    if (EnviNumber >= 1 && EnviNumber <= 10)
    {
        EnviNumber = 1;
    }
    else if (EnviNumber >= 11 && EnviNumber <= 20)
    {
        EnviNumber = 2;
    }
    else if (EnviNumber >= 21 && EnviNumber <= 30)
    {
        EnviNumber = 3;
    }
    else if ((EnviNumber >= 31 && EnviNumber <= 39) || EnviNumber == 0)
    {
        EnviNumber = 4;
    }

    switch (EnviNumber)
    {
        case 1:
            Environment = "Canyon";
            break;
        case 2:
            Environment = "Valley";
            break;
        case 3:
            Environment = "Lagoon";
            break;
        case 4:
            Environment = "Stadium";
            break;
    }

    Environment = "0" + EnviNumber + "_" + Environment;

    MapPath = "Campaigns/" + Flag + "/" + Environment + "/" + map + ".Map.Gbx";

    return MapPath;
}

void PlayMap(const string &in MapLoc)
{
    cast<CGameManiaPlanet>(GetApp()).ManiaTitleFlowScriptAPI.PlayMap(MapLoc, "TrackMania/TMC_CampaignSolo.Script.txt", "");
}

string GetSoloKind(const string &in GhostKind)
{
    if (GhostKind.StartsWith("Solo")) return "Solo";
    return "Double Driver";
}

void RenderMatch(Match Match)
{
    UI::PushFont(Monospace);
    UI::Text(tostring(Match));
    if (UI::IsItemHovered())
    {
        UI::BeginTooltip();
        UI::Text("UID " + Match.MapUID + " matched with map #" + Match.MapNum + "'s UID\nThis ghost was driven in " + Match.GhostSolo);
        UI::EndTooltip();
    }
    if (UI::IsItemClicked())
    {
        OpenExplorerPath(Match.GhostFile.FullFileName.SubStr(0, Match.GhostFile.FullFileName.Length - Match.GhostFileName.Length));
        // HandleConvertGhostToReplay(Match);
    }
    UI::PopFont();
}

void HandleConvertGhostToReplay(Match Match)
{
    auto EmptyReplay = LocateEmptyReplay();
    if (EmptyReplay is null)
    {
        UI::ShowNotification("To edit this ghost, you must have an empty replay in your Documents/Replays/Replays/ folder.");
        return;
    }
    else
    {
        @EmptyReplay.Challenge = MapToChallenge(NumToMap(Match.MapNum));
        // Dev::SetOffset(CMwNod(EmptyReplay.Ghosts[0]), 0, CMwNod(Match.Ghost));
        // Dev::SetOffset(cast<CMwNod>(EmptyReplay.Ghosts[0]), Reflection::GetType("CMwNod").GetMember("Id").Offset, cast<CMwNod>(Match.Ghost).Id.Value);
        ExploreNod(EmptyReplay);
        ExploreNod(Match.Ghost);
    }
}

CGameCtnReplayRecord@ LocateEmptyReplay()
{
    auto File = Fids::GetUser("Replays/Replays/EmptyReplay.Replay.Gbx");
    if (File is null) return null;
    auto Nod = Fids::Preload(File);
    if (Nod is null) return null;
    return cast<CGameCtnReplayRecord>(Nod);
}

void ForceLoadAllGhosts()
{
    Fids::UpdateTree(MapsGhostsFolder);
    if (MapsGhostsFolder !is null)
    {
        for (uint i = 0; i < 400; i++)
        {
            print(i);
            auto Fid = Fids::GetUser(ProfileFolder.DirName + "/" + MapsGhostsFolder.DirName + "/" + i + ".Ghost.Gbx");
            if (Fid is null) print(i + ".Ghost.Gbx is null.");
            else print(i + ".Ghost.Gbx found.");
        }
    }
    Done = false;
}

string NextMap(const string &in map)
{
    int mapNum = Text::ParseInt(map);
    mapNum++;

    string output = tostring(mapNum);

    if (output.Length == 2)
    {
        output = "0" + output;
    }
    if (output.Length == 1)
    {
        output = "00" + output;
    }

    return output;
}

string NumToMap(int num)
{
    string output = tostring(num);

    if (output.Length == 2)
    {
        output = "0" + output;
    }
    if (output.Length == 1)
    {
        output = "00" + output;
    }

    return output;
}

string GetMapUIDFromGhost(CGameCtnGhost@ ghost)
{
    return MwId(Dev::GetOffsetUint32(ghost, 0x120)).GetName();
}