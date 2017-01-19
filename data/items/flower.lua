local item = ...

function item:on_created()
  self:set_shadow(nil)
end

function item:on_obtaining(variant, savegame_variable)
  self:set_savegame_variable("quest_flower")
end
